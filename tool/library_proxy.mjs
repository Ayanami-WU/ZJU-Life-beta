#!/usr/bin/env node
import http from 'node:http';
import https from 'node:https';

const port = Number(process.env.LIBRARY_PROXY_PORT || 51989);
const targetHost = 'booking.lib.zju.edu.cn';
const targetOrigin = `https://${targetHost}`;
const canteenHost = 'canteen.zju.edu.cn';
const casHost = 'zjuam.zju.edu.cn';
const casOrigin = `https://${casHost}`;
const libraryHomeUrl = `${targetOrigin}/h5/`;
const libraryCasGatewayPath = '/api/cas/cas';
const libraryCasGatewayUrl = `${targetOrigin}${libraryCasGatewayPath}`;
const libraryServiceUrl = `${targetOrigin}/h5/#/cas`;
const libraryServiceCandidates = [
  { label: 'h5-cas', url: `${targetOrigin}/h5/#/cas` },
  { label: 'h5-index-cas', url: `${targetOrigin}/h5/index.html#/cas` },
  { label: 'h5-root', url: `${targetOrigin}/h5/` },
  { label: 'h5-index', url: `${targetOrigin}/h5/index.html` },
];
const debug = process.env.LIBRARY_PROXY_DEBUG !== '0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers':
    'accept, accept-language, authorization, content-type, lang, x-requested-with',
  'Access-Control-Max-Age': '86400',
};

function send(res, statusCode, body, headers = {}) {
  res.writeHead(statusCode, {
    ...corsHeaders,
    'Content-Type': 'application/json; charset=utf-8',
    ...headers,
  });
  res.end(body);
}

function log(...args) {
  if (debug) console.log(new Date().toISOString(), ...args);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1024 * 1024) {
        reject(new Error('Request body is too large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function mergeCookies(current, setCookieHeaders = []) {
  const jar = new Map();
  for (const item of current.split(';')) {
    const [name, ...rest] = item.trim().split('=');
    if (name) jar.set(name, rest.join('='));
  }
  for (const header of setCookieHeaders) {
    const cookie = header.split(';')[0];
    const [name, ...rest] = cookie.trim().split('=');
    if (name) jar.set(name, rest.join('='));
  }
  return [...jar.entries()].map(([name, value]) => `${name}=${value}`).join('; ');
}

function mergeCookieHeaders(...cookieHeaders) {
  const jar = new Map();
  for (const header of cookieHeaders) {
    for (const item of String(header || '').split(';')) {
      const [name, ...rest] = item.trim().split('=');
      if (name) jar.set(name, rest.join('='));
    }
  }
  return [...jar.entries()].map(([name, value]) => `${name}=${value}`).join('; ');
}

function headerLocation(headers) {
  const location = headers.location;
  return Array.isArray(location) ? location[0] : location || '';
}

function upstreamRequest({
  hostname,
  path,
  method = 'GET',
  headers = {},
  body = Buffer.alloc(0),
}) {
  return new Promise((resolve, reject) => {
    const request = https.request(
      {
        hostname,
        path,
        method,
        headers,
        timeout: 20000,
      },
      (response) => {
        const chunks = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () => {
          resolve({
            statusCode: response.statusCode || 0,
            headers: response.headers,
            body: Buffer.concat(chunks),
          });
        });
      },
    );
    request.on('timeout', () => {
      request.destroy(new Error('Upstream request timed out'));
    });
    request.on('error', reject);
    request.end(body);
  });
}

function formEncode(data) {
  return new URLSearchParams(data).toString();
}

function decodeHtmlEntities(value) {
  return value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");
}

function extractExecution(html) {
  const direct = html.match(/name=["']execution["'][^>]*value=["']([^"']+)/i);
  if (direct) return decodeHtmlEntities(direct[1]);

  const reverse = html.match(/value=["']([^"']+)["'][^>]*name=["']execution/i);
  if (reverse) return decodeHtmlEntities(reverse[1]);

  return '';
}

function extractLoginError(html) {
  const match =
    html.match(/id=["']msg["'][^>]*>([^<]+)/i) ||
    html.match(/class=["'][^"']*(?:login-error|alert-danger)[^"']*["'][^>]*>([^<]+)/i);
  return match ? decodeHtmlEntities(match[1].trim()) : '';
}

function encryptPassword(password, modulusHex, exponentHex) {
  const modulus = BigInt(`0x${modulusHex}`);
  const exponent = BigInt(`0x${exponentHex}`);
  const modulusWords = Math.ceil(modulusHex.length / 4);
  const chunkSize = Math.max(2, 2 * (modulusWords - 1));
  const codeUnits = [...password.split('').reverse().join('')].map((char) =>
    char.charCodeAt(0),
  );

  while (codeUnits.length % chunkSize !== 0) {
    codeUnits.push(0);
  }

  const blocks = [];
  for (let i = 0; i < codeUnits.length; i += chunkSize) {
    let block = 0n;
    for (let offset = 0, digit = 0; offset < chunkSize; offset += 2, digit++) {
      const low = codeUnits[i + offset] || 0;
      const high = codeUnits[i + offset + 1] || 0;
      block += BigInt(low + (high << 8)) << BigInt(16 * digit);
    }

    let encrypted = modPow(block, exponent, modulus).toString(16);
    encrypted = encrypted.padStart(Math.ceil(encrypted.length / 4) * 4, '0');
    blocks.push(encrypted);
  }

  return blocks.join(' ');
}

function modPow(base, exponent, modulus) {
  if (modulus === 1n) return 0n;
  let result = 1n;
  let b = base % modulus;
  let e = exponent;
  while (e > 0n) {
    if (e & 1n) result = (result * b) % modulus;
    e >>= 1n;
    b = (b * b) % modulus;
  }
  return result;
}

function extractTicket(location) {
  if (!location) return '';
  const url = new URL(location, libraryHomeUrl);
  const searchTicket =
    url.searchParams.get('cas') || url.searchParams.get('ticket') || '';
  if (searchTicket) return searchTicket;

  const hash = url.hash.startsWith('#') ? url.hash.slice(1) : url.hash;
  const queryStart = hash.indexOf('?');
  if (queryStart >= 0) {
    const hashParams = new URLSearchParams(hash.slice(queryStart + 1));
    return hashParams.get('cas') || hashParams.get('ticket') || '';
  }

  return '';
}

function cookieHeaderValue(cookieHeader, name) {
  for (const item of cookieHeader.split(';')) {
    const [cookieName, ...rest] = item.trim().split('=');
    if (cookieName === name) return rest.join('=');
  }
  return '';
}

function trimmedString(value) {
  if (typeof value !== 'string') return '';
  const token = value.trim();
  return token.length >= 16 ? token : '';
}

function extractLibraryToken(data, seen = new Set()) {
  const directCandidates = [
    data?.token,
    data?.access_token,
    data?.accessToken,
    data?.jwt,
    data?.authorization,
    data?.member,
    data?.member?.token,
    data?.data,
    data?.data?.token,
    data?.data?.access_token,
    data?.data?.accessToken,
    data?.data?.jwt,
    data?.data?.authorization,
    data?.data?.member,
    data?.data?.member?.token,
  ];

  for (const candidate of directCandidates) {
    const token = trimmedString(candidate);
    if (token) return token;
  }

  if (!data || typeof data !== 'object') return '';
  if (seen.has(data)) return '';
  seen.add(data);

  for (const [key, value] of Object.entries(data)) {
    const normalized = key.toLowerCase();
    if (
      normalized === 'token' ||
      normalized === 'access_token' ||
      normalized === 'accesstoken' ||
      normalized === 'jwt' ||
      normalized === 'authorization'
    ) {
      const token = trimmedString(value);
      if (token) return token;
    }
  }

  for (const value of Object.values(data)) {
    const token = extractLibraryToken(value, seen);
    if (token) return token;
  }

  return '';
}

function libraryExchangeCodeLooksOk(code) {
  if (code === undefined || code === null || code === '') return true;
  return String(code) === '0' || String(code) === '1';
}

function responseShape(data) {
  const member = data?.member || data?.data?.member || data?.data;
  return {
    code: data?.code,
    message: data?.message || data?.msg,
    keys: Object.keys(data || {}),
    third: data?.third,
    openIdPresent: Boolean(data?.open_id),
    memberType: Array.isArray(member) ? 'array' : typeof member,
    memberLength: Array.isArray(member) ? member.length : undefined,
    memberKeys:
      member && typeof member === 'object' && !Array.isArray(member)
        ? Object.keys(member).filter((key) => key !== 'token')
        : [],
  };
}

async function loadLibraryEntryCookies() {
  const response = await upstreamRequest({
    hostname: targetHost,
    path: '/h5/',
    headers: {
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  });
  return mergeCookies('', response.headers['set-cookie']);
}

async function requestLibraryCasGateway(libraryCookies = '') {
  const response = await upstreamRequest({
    hostname: targetHost,
    path: libraryCasGatewayPath,
    headers: {
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      Referer: libraryHomeUrl,
      ...(libraryCookies ? { Cookie: libraryCookies } : {}),
    },
  });

  return {
    statusCode: response.statusCode,
    cookies: mergeCookies(libraryCookies, response.headers['set-cookie']),
    location: headerLocation(response.headers),
  };
}

async function loadLibraryCallback(location, libraryCookies = '') {
  if (!location) {
    return {
      statusCode: 0,
      cookies: libraryCookies,
      location: '',
      redirects: [],
      body: Buffer.alloc(0),
    };
  }

  let nextLocation = location;
  let cookies = libraryCookies;
  let lastResult = {
    statusCode: 0,
    cookies,
    location,
    redirects: [],
    body: Buffer.alloc(0),
  };

  for (let redirectCount = 0; redirectCount < 8; redirectCount++) {
    const url = new URL(nextLocation, libraryCasGatewayUrl);
    if (url.hostname !== targetHost) {
      return {
        ...lastResult,
        location: url.toString(),
      };
    }

    // Browser-side hash routes are not sent to the server. Once the library
    // gateway redirects to #/cas/?cas=..., the frontend will exchange that cas.
    if (extractTicket(url.toString()) && url.hash) {
      return {
        ...lastResult,
        cookies,
        location: url.toString(),
      };
    }

    const response = await upstreamRequest({
      hostname: targetHost,
      path: `${url.pathname}${url.search}`,
      headers: {
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        Referer: url.toString(),
        ...(cookies ? { Cookie: cookies } : {}),
      },
    });

    cookies = mergeCookies(cookies, response.headers['set-cookie']);
    const responseLocation = headerLocation(response.headers);
    const absoluteLocation = responseLocation
      ? new URL(responseLocation, url).toString()
      : '';
    const redirects = absoluteLocation
      ? [...lastResult.redirects, absoluteLocation]
      : lastResult.redirects;
    lastResult = {
      statusCode: response.statusCode,
      cookies,
      location: absoluteLocation,
      redirects,
      body: response.body,
    };

    if (!absoluteLocation) return lastResult;
    nextLocation = absoluteLocation;
  }

  return lastResult;
}

async function loadLibraryCallbackCookies(location, libraryCookies = '') {
  const callback = await loadLibraryCallback(location, libraryCookies);
  return callback.cookies;
}

async function exchangeTicket(ticket, libraryCookies = '', referer = libraryHomeUrl) {
  const body = Buffer.from(JSON.stringify({ cas: ticket }));
  return upstreamRequest({
    hostname: targetHost,
    path: '/api/cas/user',
    method: 'POST',
    headers: {
      Accept: 'application/json, text/plain, */*',
      'Content-Type': 'application/json',
      'Content-Length': body.length,
      'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      Referer: referer || libraryHomeUrl,
      Origin: targetOrigin,
      'X-Requested-With': 'XMLHttpRequest',
      lang: 'zh',
      ...(libraryCookies ? { Cookie: libraryCookies } : {}),
    },
    body,
  });
}

async function fetchCasLoginPage(loginPath) {
  return upstreamRequest({
    hostname: casHost,
    path: loginPath,
    headers: {
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  });
}

async function fetchCasPublicKey(cookies) {
  return upstreamRequest({
    hostname: casHost,
    path: '/cas/v2/getPubKey',
    headers: {
      Accept: 'application/json, text/plain, */*',
      Cookie: cookies,
      'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  });
}

async function submitCasLogin({
  loginPath,
  username,
  password,
  execution,
  cookies,
}) {
  const pubkeyResponse = await fetchCasPublicKey(cookies);
  log('[auth] pubkey status', pubkeyResponse.statusCode);
  cookies = mergeCookies(cookies, pubkeyResponse.headers['set-cookie']);

  let encryptedPassword = password;
  try {
    const pubkey = JSON.parse(pubkeyResponse.body.toString('utf8'));
    if (pubkey.modulus && pubkey.exponent) {
      encryptedPassword = encryptPassword(
        password,
        String(pubkey.modulus),
        String(pubkey.exponent),
      );
    }
  } catch {
    encryptedPassword = password;
  }

  const formBody = Buffer.from(
    formEncode({
      username,
      password: encryptedPassword,
      authcode: '',
      execution,
      _eventId: 'submit',
      geolocation: '',
      rememberMe: 'true',
    }),
  );
  const loginResponse = await upstreamRequest({
    hostname: casHost,
    path: loginPath,
    method: 'POST',
    headers: {
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': formBody.length,
      Cookie: cookies,
      Origin: casOrigin,
      Referer: `${casOrigin}${loginPath}`,
      'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    },
    body: formBody,
  });

  return {
    response: loginResponse,
    cookies: mergeCookies(cookies, loginResponse.headers['set-cookie']),
  };
}

async function loginCasSso(username, password) {
  const loginPath = '/cas/login';
  const loginPage = await fetchCasLoginPage(loginPath);
  log('[auth] login page status', loginPage.statusCode);

  let cookies = mergeCookies('', loginPage.headers['set-cookie']);
  const html = loginPage.body.toString('utf8');
  const execution = extractExecution(html);
  if (!execution) {
    throw new Error('无法获取 CAS 登录参数');
  }

  const { response, cookies: mergedCookies } = await submitCasLogin({
    loginPath,
    username,
    password,
    execution,
    cookies,
  });
  log('[auth] cas submit status', response.statusCode);
  cookies = mergedCookies;

  const ssoValue = cookieHeaderValue(cookies, 'iPlanetDirectoryPro');
  if (!ssoValue) {
    const message =
      extractLoginError(response.body.toString('utf8')) ||
      'CAS 登录失败，请检查账号密码或验证码/风控状态';
    log('[auth] cas rejected', message);
    const error = new Error(message);
    error.statusCode = 401;
    throw error;
  }

  return cookies;
}

async function requestServiceTicket(ssoCookies, serviceUrl = libraryServiceUrl) {
  const serviceParam = encodeURIComponent(serviceUrl);
  const loginPath = `/cas/login?service=${serviceParam}`;
  return requestServiceTicketFromLoginPath(ssoCookies, loginPath);
}

async function requestServiceTicketFromLoginPath(ssoCookies, loginPath) {
  const ticketResponse = await upstreamRequest({
    hostname: casHost,
    path: loginPath,
    headers: {
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      Cookie: ssoCookies,
      'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  });

  const location = headerLocation(ticketResponse.headers);
  return {
    statusCode: ticketResponse.statusCode,
    location,
    ticket: extractTicket(location),
  };
}

function casLoginPathFromLocation(location) {
  if (!location) return '';
  const url = new URL(location, casOrigin);
  if (url.hostname !== casHost) return '';
  return `${url.pathname}${url.search}`;
}

function absoluteLibraryUrl(location, fallback = libraryHomeUrl) {
  if (!location) return fallback;
  try {
    return new URL(location, fallback).toString();
  } catch {
    return fallback;
  }
}

function tokenDebugShape(token) {
  const value = String(token || '');
  return {
    present: Boolean(value),
    length: value.length,
    startsWithST: value.startsWith('ST-'),
  };
}

function locationDebugShape(location) {
  if (!location) {
    return { present: false };
  }
  try {
    const url = new URL(location, libraryHomeUrl);
    const hash = url.hash.startsWith('#') ? url.hash.slice(1) : url.hash;
    const queryStart = hash.indexOf('?');
    const hashParams =
      queryStart >= 0 ? new URLSearchParams(hash.slice(queryStart + 1)) : null;
    const cas =
      url.searchParams.get('cas') ||
      url.searchParams.get('ticket') ||
      hashParams?.get('cas') ||
      hashParams?.get('ticket') ||
      '';
    return {
      present: true,
      host: url.hostname,
      path: url.pathname,
      searchKeys: [...url.searchParams.keys()],
      hashPath: queryStart >= 0 ? hash.slice(0, queryStart) : hash,
      hashKeys: hashParams ? [...hashParams.keys()] : [],
      cas: tokenDebugShape(cas),
    };
  } catch {
    return { present: true, parseable: false };
  }
}

async function exchangeWithOfficialCasGateway(ssoCookies, libraryCookies) {
  const label = 'official-cas-gateway';
  const attempts = [];
  const gateway = await requestLibraryCasGateway(
    mergeCookieHeaders(libraryCookies, ssoCookies),
  );
  log('[auth] library cas gateway status', gateway.statusCode);
  log('[auth] library cas gateway redirect', Boolean(gateway.location));

  const loginPath = casLoginPathFromLocation(gateway.location);
  if (!loginPath) {
    attempts.push({
      label,
      statusCode: gateway.statusCode,
      hasTicket: false,
      hasToken: false,
      shape: { message: '图书馆 CAS 入口没有跳转到统一身份认证' },
    });
    return { ok: false, ticket: '', libraryJwt: '', attempts };
  }

  const serviceTicket = await requestServiceTicketFromLoginPath(
    ssoCookies,
    loginPath,
  );
  log('[auth] service ticket status', label, serviceTicket.statusCode);
  log('[auth] cas redirected with ticket', label, Boolean(serviceTicket.ticket));

  if (!serviceTicket.ticket) {
    attempts.push({
      label,
      statusCode: serviceTicket.statusCode,
      hasTicket: false,
      hasToken: false,
      shape: { message: '统一身份认证没有返回图书馆 ticket' },
    });
    return { ok: false, ticket: '', libraryJwt: '', attempts };
  }

  const callback = await loadLibraryCallback(
    serviceTicket.location,
    mergeCookieHeaders(gateway.cookies, ssoCookies),
  );
  log('[auth] library callback status', label, callback.statusCode);
  log('[auth] library callback redirect', label, Boolean(callback.location));
  log('[auth] library callback location shape', label, locationDebugShape(callback.location));
  log(
    '[auth] library callback redirect chain',
    label,
    callback.redirects.map(locationDebugShape),
  );

  let callbackData = {};
  try {
    callbackData = JSON.parse(callback.body.toString('utf8') || '{}');
  } catch {
    callbackData = {};
  }

  const callbackToken = extractLibraryToken(callbackData);
  const callbackCas = extractTicket(callback.location);
  const ticket = callbackCas || serviceTicket.ticket;
  log('[auth] token source', label, {
    serviceTicket: tokenDebugShape(serviceTicket.ticket),
    callbackCas: tokenDebugShape(callbackCas),
    usingCallbackCas: Boolean(callbackCas),
  });
  if (callbackToken) {
    attempts.push({
      label,
      statusCode: callback.statusCode,
      hasTicket: Boolean(ticket),
      hasToken: true,
      shape: responseShape(callbackData),
    });
    return {
      ok: true,
      ticket,
      libraryJwt: callbackToken,
      attempts,
    };
  }

  const jwtResponse = await exchangeTicket(
    ticket,
    mergeCookieHeaders(callback.cookies, ssoCookies),
    absoluteLibraryUrl(callback.location, serviceTicket.location || libraryCasGatewayUrl),
  );
  log('[auth] library token status', label, jwtResponse.statusCode);

  let jwtData = {};
  try {
    jwtData = JSON.parse(jwtResponse.body.toString('utf8') || '{}');
  } catch {
    jwtData = {};
  }

  const libraryJwt = extractLibraryToken(jwtData);
  const attempt = {
    label,
    statusCode: jwtResponse.statusCode,
    hasTicket: Boolean(ticket),
    hasToken: Boolean(libraryJwt),
    shape: responseShape(jwtData),
  };
  attempts.push(attempt);

  if (
    jwtResponse.statusCode === 200 &&
    libraryExchangeCodeLooksOk(jwtData.code) &&
    libraryJwt
  ) {
    return {
      ok: true,
      ticket,
      libraryJwt,
      attempts,
    };
  }

  log('[auth] library token rejected', {
    label,
    ...attempt.shape,
  });

  return { ok: false, ticket: '', libraryJwt: '', attempts };
}

async function exchangeWithServiceCandidates(ssoCookies, libraryCookies) {
  const official = await exchangeWithOfficialCasGateway(ssoCookies, libraryCookies);
  if (official.ok) return official;

  const attempts = [...official.attempts];

  for (const candidate of libraryServiceCandidates) {
    const serviceTicket = await requestServiceTicket(ssoCookies, candidate.url);
    log('[auth] service ticket status', candidate.label, serviceTicket.statusCode);
    log('[auth] cas redirected with ticket', candidate.label, Boolean(serviceTicket.ticket));

    if (!serviceTicket.ticket) {
      attempts.push({
        label: candidate.label,
        statusCode: serviceTicket.statusCode,
        hasTicket: false,
      });
      continue;
    }

    const callbackCookies = await loadLibraryCallbackCookies(
      serviceTicket.location,
      mergeCookieHeaders(libraryCookies, ssoCookies),
    );
    log('[auth] library callback cookies', candidate.label, Boolean(callbackCookies));

    const jwtResponse = await exchangeTicket(
      serviceTicket.ticket,
      mergeCookieHeaders(callbackCookies, ssoCookies),
      serviceTicket.location || candidate.url,
    );
    log('[auth] library token status', candidate.label, jwtResponse.statusCode);

    let jwtData = {};
    try {
      jwtData = JSON.parse(jwtResponse.body.toString('utf8') || '{}');
    } catch {
      jwtData = {};
    }

    const libraryJwt = extractLibraryToken(jwtData);
    const attempt = {
      label: candidate.label,
      statusCode: jwtResponse.statusCode,
      hasTicket: true,
      hasToken: Boolean(libraryJwt),
      shape: responseShape(jwtData),
    };
    attempts.push(attempt);

    if (
      jwtResponse.statusCode === 200 &&
      libraryExchangeCodeLooksOk(jwtData.code) &&
      libraryJwt
    ) {
      return {
        ok: true,
        ticket: serviceTicket.ticket,
        libraryJwt,
        attempts,
      };
    }

    log('[auth] library token rejected', {
      label: candidate.label,
      ...attempt.shape,
    });
  }

  return { ok: false, ticket: '', libraryJwt: '', attempts };
}

async function handleAuthLogin(req, res) {
  log('[auth] login request received');
  const body = await readBody(req);
  const payload = JSON.parse(body.toString('utf8') || '{}');
  const username = String(payload.username || '').trim();
  const password = String(payload.password || '');

  if (!username || !password) {
    send(res, 400, JSON.stringify({ success: false, message: '请输入账号和密码' }));
    return;
  }

  const cookies = await loginCasSso(username, password);
  log('[auth] sso cookie received', Boolean(cookieHeaderValue(cookies, 'iPlanetDirectoryPro')));

  const libraryCookies = await loadLibraryEntryCookies();
  log('[auth] library entry cookies', Boolean(libraryCookies));

  const exchange = await exchangeWithServiceCandidates(cookies, libraryCookies);
  if (!exchange.ok) {
    const attempts = exchange.attempts.map((attempt) => ({
      label: attempt.label,
      statusCode: attempt.statusCode,
      hasTicket: attempt.hasTicket,
      hasToken: attempt.hasToken,
      code: attempt.shape?.code,
      message: attempt.shape?.message,
    }));
    log('[auth] all library token attempts rejected', attempts);
    send(
      res,
      502,
      JSON.stringify({
        success: false,
        message: '图书馆授权失败',
        attempts,
      }),
    );
    return;
  }

  send(
    res,
    200,
    JSON.stringify({
      success: true,
      userId: username,
      userName: username,
      cookie: cookies,
      ticket: exchange.ticket,
      libraryJwt: exchange.libraryJwt,
    }),
  );
  log('[auth] login completed');
}

function forward(path, body, req, res) {
  const headers = {
    Accept: 'application/json, text/plain, */*',
    'Content-Type': req.headers['content-type'] || 'application/json',
    'Content-Length': body.length,
    'User-Agent':
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    Referer: `${targetOrigin}/h5/index.html`,
    Origin: targetOrigin,
    'X-Requested-With': 'XMLHttpRequest',
  };

  if (req.headers.authorization) {
    headers.authorization = req.headers.authorization;
  }
  if (req.headers.lang) {
    headers.lang = req.headers.lang;
  }

  const proxyReq = https.request(
    {
      hostname: targetHost,
      path,
      method: 'POST',
      headers,
      timeout: 20000,
    },
    (proxyRes) => {
      const chunks = [];
      proxyRes.on('data', (chunk) => chunks.push(chunk));
      proxyRes.on('end', () => {
        const responseBody = Buffer.concat(chunks);
        if (
          path.startsWith('/reserve/index/list') ||
          path.startsWith('/api/Seat/seat') ||
          path.startsWith('/api/seat/map')
        ) {
          let shape = {};
          try {
            const data = JSON.parse(responseBody.toString('utf8') || '{}');
            const list = data?.data?.list ?? data?.data;
            let requestShape = {};
            if (path.startsWith('/reserve/index/list')) {
              try {
                const requestData = JSON.parse(body.toString('utf8') || '{}');
                requestShape = {
                  requestId: requestData.id,
                  requestDate: requestData.date,
                  requestCategoryIds: requestData.categoryIds,
                  requestPage: requestData.page,
                  requestSize: requestData.size,
                };
              } catch {
                requestShape = { requestParseable: false };
              }
            }
            shape = {
              ...requestShape,
              code: data?.code,
              message: data?.message || data?.msg,
              count: data?.data?.count,
              listLength: Array.isArray(list) ? list.length : undefined,
            };
          } catch {
            shape = { parseable: false };
          }
          log('[proxy] library forward', {
            path,
            statusCode: proxyRes.statusCode,
            hasAuthorization: Boolean(headers.authorization),
            ...shape,
          });
        }
        send(res, proxyRes.statusCode || 502, responseBody, {
          'Content-Type':
            proxyRes.headers['content-type'] ||
            'application/json; charset=utf-8',
        });
      });
    },
  );

  proxyReq.on('timeout', () => {
    proxyReq.destroy(new Error('Upstream request timed out'));
  });
  proxyReq.on('error', (error) => {
    send(
      res,
      502,
      JSON.stringify({
        code: 502,
        message: `Library proxy failed: ${error.message}`,
      }),
    );
  });
  proxyReq.end(body);
}

function forwardCanteen(path, res) {
  const proxyReq = https.request(
    {
      hostname: canteenHost,
      path,
      method: 'GET',
      headers: {
        Accept: '*/*',
        'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
      timeout: 20000,
    },
    (proxyRes) => {
      const chunks = [];
      proxyRes.on('data', (chunk) => chunks.push(chunk));
      proxyRes.on('end', () => {
        send(res, proxyRes.statusCode || 502, Buffer.concat(chunks), {
          'Content-Type':
            proxyRes.headers['content-type'] ||
            'application/json; charset=utf-8',
        });
      });
    },
  );

  proxyReq.on('timeout', () => {
    proxyReq.destroy(new Error('Upstream request timed out'));
  });
  proxyReq.on('error', (error) => {
    send(
      res,
      502,
      JSON.stringify({
        code: 502,
        message: `Canteen proxy failed: ${error.message}`,
      }),
    );
  });
  proxyReq.end();
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    send(res, 204, '');
    return;
  }

  const url = new URL(req.url || '/', `http://127.0.0.1:${port}`);
  if (req.method === 'POST' && url.pathname === '/auth/login') {
    try {
      await handleAuthLogin(req, res);
    } catch (error) {
      log('[auth] login proxy failed', error.message);
      send(
        res,
        error.statusCode || 502,
        JSON.stringify({
          success: false,
          message: `Login proxy failed: ${error.message}`,
        }),
      );
    }
    return;
  }

  if (req.method === 'GET' && url.pathname === '/canteen/general_new.php') {
    forwardCanteen(`/monitor/general_new.php${url.search}`, res);
    return;
  }

  const proxiedPrefix =
    url.pathname.startsWith('/api/') || url.pathname.startsWith('/reserve/');
  if (req.method !== 'POST' || !proxiedPrefix) {
    send(
      res,
      404,
      JSON.stringify({
        code: 404,
        message:
          'Only POST /api/*, POST /reserve/*, and GET /canteen/general_new.php are proxied',
      }),
    );
    return;
  }

  try {
    const body = await readBody(req);
    forward(`${url.pathname}${url.search}`, body, req, res);
  } catch (error) {
    send(
      res,
      400,
      JSON.stringify({
        code: 400,
        message: error.message,
      }),
    );
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Library proxy listening at http://127.0.0.1:${port}`);
});
