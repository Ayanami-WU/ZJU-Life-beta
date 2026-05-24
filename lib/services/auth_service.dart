import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../config/constants.dart';

/// ZJU CAS 统一身份认证服务
class AuthService {
  static AuthService? _instance;
  late final Dio _dio;

  static const String _casBaseUrl = 'https://zjuam.zju.edu.cn/cas';
  static const String _casLoginUrl = '$_casBaseUrl/login';
  static const String _pubkeyUrl = '$_casBaseUrl/v2/getPubKey';
  static const String _bookingBaseUrl = 'https://booking.lib.zju.edu.cn';
  static const String _libraryServiceUrl = '$_bookingBaseUrl/h5/';
  static const String _libraryCasGatewayPath = '/api/cas/cas';
  static const String _libraryCasGatewayUrl =
      '$_bookingBaseUrl$_libraryCasGatewayPath';
  static const String _libraryCasApi = '$_bookingBaseUrl/api/cas/user';
  static const List<_LibraryServiceCandidate> _libraryServiceCandidates = [
    _LibraryServiceCandidate('h5-cas', '$_bookingBaseUrl/h5/#/cas'),
    _LibraryServiceCandidate(
        'h5-index-cas', '$_bookingBaseUrl/h5/index.html#/cas'),
    _LibraryServiceCandidate('h5-root', _libraryServiceUrl),
    _LibraryServiceCandidate('h5-index', '$_bookingBaseUrl/h5/index.html'),
  ];

  static String casLoginUrlForService(String service) {
    return '$_casLoginUrl?service=${Uri.encodeComponent(service)}';
  }

  AuthService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers.putIfAbsent(
          'User-Agent',
          () =>
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        );
        options.headers.putIfAbsent(
          'Accept',
          () =>
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        );
        options.headers.putIfAbsent(
          'Accept-Language',
          () => 'zh-CN,zh;q=0.9,en;q=0.8',
        );
        return handler.next(options);
      },
    ));
  }

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  /// 登录 CAS 系统
  Future<LoginResult> login(String username, String password) async {
    if (kIsWeb) {
      return _loginWithLocalProxy(username, password);
    }

    try {
      final loginPageResponse = await _dio.get(_casLoginUrl);

      final document = html_parser.parse(loginPageResponse.data);
      final executionInput = document.querySelector('input[name="execution"]');
      final execution = executionInput?.attributes['value'] ?? '';

      if (execution.isEmpty) {
        throw AuthException('无法获取登录参数，请稍后重试');
      }

      final setCookieHeaders = loginPageResponse.headers['set-cookie'];
      String cookies = '';
      if (setCookieHeaders != null) {
        cookies = setCookieHeaders.map((c) => c.split(';')[0]).join('; ');
      }

      final pubkeyResponse = await _dio.get(
        _pubkeyUrl,
        options: Options(headers: {'Cookie': cookies}),
      );
      cookies = _mergeCookies(cookies, pubkeyResponse.headers['set-cookie']);

      String encryptedPassword = password;
      if (pubkeyResponse.statusCode == 200 && pubkeyResponse.data != null) {
        try {
          final pubkeyData = pubkeyResponse.data is String
              ? json.decode(pubkeyResponse.data)
              : pubkeyResponse.data;
          final modulus = pubkeyData['modulus'] as String?;
          final exponent = pubkeyData['exponent'] as String?;
          if (modulus != null && exponent != null) {
            encryptedPassword = _rsaEncrypt(password, modulus, exponent);
          }
        } catch (_) {}
      }

      final loginResponse = await _dio.post(
        _casLoginUrl,
        data: _buildCasLoginFormBody(
          username: username,
          encryptedPassword: encryptedPassword,
          execution: execution,
        ),
        options: Options(
          headers: {
            'Cookie': cookies,
            'Content-Type': 'application/x-www-form-urlencoded',
            'Origin': 'https://zjuam.zju.edu.cn',
            'Referer': _casLoginUrl,
          },
          followRedirects: false,
        ),
      );

      if (loginResponse.statusCode == 302) {
        final newCookies = loginResponse.headers['set-cookie'];
        if (newCookies != null) {
          final newCookieStr =
              newCookies.map((c) => c.split(';')[0]).join('; ');
          cookies = '$cookies; $newCookieStr';
        }

        return LoginResult(
          success: true,
          userId: username,
          userName: username,
          cookie: cookies,
        );
      }

      final errorDoc = html_parser.parse(loginResponse.data);
      final errorSpan = errorDoc.querySelector('#msg') ??
          errorDoc.querySelector('.login-error') ??
          errorDoc.querySelector('.alert-danger');
      final errorMsg = errorSpan?.text.trim() ?? '登录失败，请检查用户名和密码';

      throw AuthException(errorMsg);
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is DioException) throw AuthException(_dioErrorMessage(e));
      throw AuthException('登录失败: $e');
    }
  }

  Future<LoginResult> _loginWithLocalProxy(
    String username,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.localLibraryProxyUrl}/auth/login',
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data =
          response.data is String ? json.decode(response.data) : response.data;
      if (data is! Map) {
        throw AuthException('登录响应格式异常');
      }

      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(data['message']?.toString() ?? '登录失败');
      }

      return LoginResult(
        success: true,
        userId: data['userId']?.toString() ?? username,
        userName: data['userName']?.toString() ?? username,
        cookie: data['cookie']?.toString(),
        ticket: data['ticket']?.toString(),
        libraryJwt: data['libraryJwt']?.toString(),
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is DioException) throw AuthException(_dioErrorMessage(e));
      throw AuthException('登录失败: $e');
    }
  }

  String _dioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '连接超时，请检查本地代理和网络';
      case DioExceptionType.connectionError:
        return '无法连接本地登录代理，请确认 51989 代理已启动';
      case DioExceptionType.badResponse:
        return '登录服务响应错误 (${e.response?.statusCode ?? "未知"})';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badCertificate:
        return '证书验证失败';
      case DioExceptionType.unknown:
        return '网络错误: ${e.message ?? "未知错误"}';
    }
  }

  /// 使用已有 CAS Cookie 为图书馆预约系统换取访问 Token。
  Future<String?> getLibraryJwt(String casCookie) async {
    try {
      final trimmedCookie = casCookie.trim();
      if (trimmedCookie.isEmpty) return null;

      final libraryCookies = await _loadLibraryEntryCookies();

      final gatewayJwt = await _exchangeWithOfficialCasGateway(
        trimmedCookie,
        libraryCookies,
      );
      if (gatewayJwt != null && gatewayJwt.isNotEmpty) {
        return gatewayJwt;
      }

      return _exchangeWithServiceCandidates(trimmedCookie, libraryCookies);
    } catch (_) {
      return null;
    }
  }

  /// 将 CAS ticket 兑换为图书馆预约系统 Token。
  Future<String?> exchangeLibraryTicket(
    String ticket, {
    String? cookies,
    String? referer,
  }) async {
    try {
      final trimmedTicket = ticket.trim();
      if (trimmedTicket.isEmpty) return null;

      const endpoint = kIsWeb
          ? '${ApiConfig.localLibraryProxyUrl}/api/cas/user'
          : _libraryCasApi;
      final headers = <String, String>{
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json',
        'Referer': referer ?? _libraryServiceUrl,
        'Origin': _bookingBaseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'lang': 'zh',
      };
      final cookieHeader = cookies?.trim();
      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        headers['Cookie'] = cookieHeader;
      }

      final jwtResponse = await _dio.post(
        endpoint,
        data: {'cas': trimmedTicket},
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = jwtResponse.data is String
          ? json.decode(jwtResponse.data)
          : jwtResponse.data;
      if (data is! Map) return null;

      if (jwtResponse.statusCode != 200) return null;

      if (!_libraryExchangeCodeLooksOk(data['code'])) {
        return null;
      }

      return _extractLibraryToken(data);
    } catch (_) {
      return null;
    }
  }

  String? _extractLibraryToken(dynamic value, {bool allowPlainString = false}) {
    if (allowPlainString) {
      final token = _tokenString(value);
      if (token != null) return token;
    }

    if (value is Iterable) {
      for (final item in value) {
        final nested = _extractLibraryToken(item);
        if (nested != null) return nested;
      }
      return null;
    }

    if (value is! Map) return null;

    const tokenKeys = {
      'token',
      'access_token',
      'accesstoken',
      'jwt',
      'authorization',
    };
    const trustedStringKeys = {'member', 'data'};

    for (final entry in value.entries) {
      final key = entry.key.toString();
      final normalized = key.toLowerCase();
      if (tokenKeys.contains(normalized)) {
        final direct = _extractLibraryToken(
          entry.value,
          allowPlainString: true,
        );
        if (direct != null) return direct;
      }
    }

    for (final key in trustedStringKeys) {
      if (!value.containsKey(key)) continue;
      final direct = _extractLibraryToken(
        value[key],
        allowPlainString: true,
      );
      if (direct != null) return direct;
    }

    for (final item in value.values) {
      final nested = _extractLibraryToken(item);
      if (nested != null) return nested;
    }

    return null;
  }

  String? _tokenString(dynamic value) {
    if (value is! String) return null;
    final token = value.trim();
    return token.length < 16 ? null : token;
  }

  Future<String> _loadLibraryEntryCookies() async {
    final response = await _dio.get(_libraryServiceUrl);
    return _mergeCookies('', response.headers['set-cookie']);
  }

  Future<String?> _exchangeWithOfficialCasGateway(
    String ssoCookies,
    String libraryCookies,
  ) async {
    final gateway = await _requestLibraryCasGateway(
      _mergeCookieValues([libraryCookies, ssoCookies]),
    );

    final loginPath = casLoginPathFromLocation(gateway.location);
    if (loginPath.isEmpty) return null;

    final serviceTicket = await _requestServiceTicketFromLoginPath(
      ssoCookies,
      loginPath,
    );
    if (serviceTicket.ticket.isEmpty) return null;

    final callback = await _loadLibraryCallback(
      serviceTicket.location,
      _mergeCookieValues([gateway.cookies, ssoCookies]),
    );

    final callbackToken = _extractLibraryToken(callback.data);
    final callbackTicket = extractTicketFromLocation(callback.location);
    final ticket = callbackTicket ?? serviceTicket.ticket;
    if (callbackToken != null && callbackToken.isNotEmpty) {
      return callbackToken;
    }

    return exchangeLibraryTicket(
      ticket,
      cookies: _mergeCookieValues([callback.cookies, ssoCookies]),
      referer: _absoluteLibraryUrl(
        callback.location,
        fallback: serviceTicket.location.isNotEmpty
            ? serviceTicket.location
            : _libraryCasGatewayUrl,
      ),
    );
  }

  Future<String?> _exchangeWithServiceCandidates(
    String ssoCookies,
    String libraryCookies,
  ) async {
    for (final candidate in _libraryServiceCandidates) {
      final serviceTicket = await _requestServiceTicket(
        ssoCookies,
        serviceUrl: candidate.url,
      );
      if (serviceTicket.ticket.isEmpty) continue;

      final callbackCookies = await _loadLibraryCallbackCookies(
        serviceTicket.location,
        _mergeCookieValues([libraryCookies, ssoCookies]),
      );

      final libraryJwt = await exchangeLibraryTicket(
        serviceTicket.ticket,
        cookies: _mergeCookieValues([callbackCookies, ssoCookies]),
        referer: serviceTicket.location.isNotEmpty
            ? serviceTicket.location
            : candidate.url,
      );
      if (libraryJwt != null && libraryJwt.isNotEmpty) {
        return libraryJwt;
      }
    }

    return null;
  }

  Future<_LibraryGatewayResult> _requestLibraryCasGateway(
      String cookies) async {
    final response = await _dio.get(
      '$_bookingBaseUrl$_libraryCasGatewayPath',
      options: Options(
        headers: {
          'Referer': _libraryServiceUrl,
          if (cookies.isNotEmpty) 'Cookie': cookies,
        },
      ),
    );

    return _LibraryGatewayResult(
      statusCode: response.statusCode ?? 0,
      cookies: _mergeCookies(cookies, response.headers['set-cookie']),
      location: _headerLocation(response.headers),
    );
  }

  Future<_LibraryServiceTicketResult> _requestServiceTicket(
    String ssoCookies, {
    String serviceUrl = _libraryServiceUrl,
  }) async {
    final serviceParam = Uri.encodeComponent(serviceUrl);
    final loginPath = '/cas/login?service=$serviceParam';
    return _requestServiceTicketFromLoginPath(ssoCookies, loginPath);
  }

  Future<_LibraryServiceTicketResult> _requestServiceTicketFromLoginPath(
    String ssoCookies,
    String loginPath,
  ) async {
    final response = await _dio.get(
      'https://zjuam.zju.edu.cn$loginPath',
      options: Options(
        headers: {'Cookie': ssoCookies},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final location = _headerLocation(response.headers);
    return _LibraryServiceTicketResult(
      statusCode: response.statusCode ?? 0,
      location: location,
      ticket: extractTicketFromLocation(location) ?? '',
    );
  }

  Future<String> _loadLibraryCallbackCookies(
    String location,
    String libraryCookies,
  ) async {
    final callback = await _loadLibraryCallback(location, libraryCookies);
    return callback.cookies;
  }

  Future<_LibraryCallbackResult> _loadLibraryCallback(
    String location,
    String libraryCookies,
  ) async {
    if (location.isEmpty) {
      return const _LibraryCallbackResult(
        statusCode: 0,
        cookies: '',
        location: '',
        redirects: [],
        data: null,
      );
    }

    var nextLocation = location;
    var cookies = libraryCookies;
    var lastResult = _LibraryCallbackResult(
      statusCode: 0,
      cookies: cookies,
      location: location,
      redirects: const [],
      data: null,
    );

    for (var redirectCount = 0; redirectCount < 8; redirectCount++) {
      final url = Uri.parse(_absoluteLibraryUrl(nextLocation));
      if (url.host != Uri.parse(_bookingBaseUrl).host) {
        return _LibraryCallbackResult(
          statusCode: lastResult.statusCode,
          cookies: cookies,
          location: url.toString(),
          redirects: lastResult.redirects,
          data: lastResult.data,
        );
      }

      if (extractTicketFromLocation(url.toString()) != null &&
          url.fragment.isNotEmpty) {
        return _LibraryCallbackResult(
          statusCode: lastResult.statusCode,
          cookies: cookies,
          location: url.toString(),
          redirects: lastResult.redirects,
          data: lastResult.data,
        );
      }

      final requestUri = url.fragment.isEmpty ? url : url.replace(fragment: '');
      final response = await _dio.getUri(
        requestUri,
        options: Options(
          headers: {
            'Referer': url.toString(),
            if (cookies.isNotEmpty) 'Cookie': cookies,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      cookies = _mergeCookies(cookies, response.headers['set-cookie']);
      final responseLocation = _headerLocation(response.headers);
      final absoluteLocation = responseLocation.isEmpty
          ? ''
          : requestUri.resolve(responseLocation).toString();
      final redirects = absoluteLocation.isEmpty
          ? lastResult.redirects
          : [...lastResult.redirects, absoluteLocation];

      lastResult = _LibraryCallbackResult(
        statusCode: response.statusCode ?? 0,
        cookies: cookies,
        location: absoluteLocation,
        redirects: redirects,
        data: response.data,
      );

      if (absoluteLocation.isEmpty) return lastResult;
      nextLocation = absoluteLocation;
    }

    return lastResult;
  }

  static String? extractTicketFromLocation(String? location) {
    if (location == null || location.isEmpty) return null;
    try {
      final uri = Uri.parse(_absoluteLibraryUrl(location));
      final queryTicket =
          uri.queryParameters['cas'] ?? uri.queryParameters['ticket'];
      if (queryTicket != null && queryTicket.isNotEmpty) {
        return queryTicket;
      }

      final fragment = uri.fragment;
      if (fragment.isEmpty) return null;

      final queryStart = fragment.indexOf('?');
      if (queryStart < 0 || queryStart >= fragment.length - 1) {
        return null;
      }

      final hashParams =
          Uri.splitQueryString(fragment.substring(queryStart + 1));
      final hashTicket = hashParams['cas'] ?? hashParams['ticket'];
      if (hashTicket == null || hashTicket.isEmpty) return null;
      return hashTicket;
    } catch (_) {
      return null;
    }
  }

  static String casLoginPathFromLocation(String? location) {
    if (location == null || location.isEmpty) return '';
    try {
      final uri = Uri.parse('https://zjuam.zju.edu.cn').resolve(location);
      if (uri.host != 'zjuam.zju.edu.cn') return '';
      return '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    } catch (_) {
      return '';
    }
  }

  static String _absoluteLibraryUrl(
    String? location, {
    String fallback = _libraryServiceUrl,
  }) {
    if (location == null || location.isEmpty) return fallback;
    try {
      return Uri.parse(fallback).resolve(location).toString();
    } catch (_) {
      return fallback;
    }
  }

  String _headerLocation(Headers headers) {
    final locationHeader = headers['location'];
    if (locationHeader == null || locationHeader.isEmpty) return '';
    return locationHeader.first;
  }

  bool _libraryExchangeCodeLooksOk(dynamic code) {
    if (code == null || code == '') return true;
    final text = code.toString();
    return text == '0' || text == '1';
  }

  String _mergeCookies(String current, List<String>? setCookieHeaders) {
    final jar = <String, String>{};

    void addCookiePair(String rawCookie) {
      final trimmed = rawCookie.trim();
      if (trimmed.isEmpty || !trimmed.contains('=')) return;
      final index = trimmed.indexOf('=');
      final name = trimmed.substring(0, index).trim();
      final value = trimmed.substring(index + 1).trim();
      if (name.isEmpty) return;
      jar[name] = value;
    }

    if (current.isNotEmpty) {
      for (final cookie in current.split(';')) {
        addCookiePair(cookie);
      }
    }

    for (final header in setCookieHeaders ?? const <String>[]) {
      final firstCookie = header.split(';').first;
      addCookiePair(firstCookie);
    }

    return jar.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  String _mergeCookieValues(Iterable<String?> cookieHeaders) {
    final jar = <String, String>{};

    for (final header in cookieHeaders) {
      if (header == null || header.trim().isEmpty) continue;
      for (final cookie in header.split(';')) {
        final trimmed = cookie.trim();
        if (trimmed.isEmpty || !trimmed.contains('=')) continue;
        final index = trimmed.indexOf('=');
        final name = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();
        if (name.isEmpty) continue;
        jar[name] = value;
      }
    }

    return jar.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  String _buildCasLoginFormBody({
    required String username,
    required String encryptedPassword,
    required String execution,
  }) {
    final form = <String, String>{
      'username': username,
      'password': encryptedPassword,
      'authcode': '',
      'execution': execution,
      '_eventId': 'submit',
      'geolocation': '',
      'rememberMe': 'true',
    };

    return form.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  String _rsaEncrypt(String password, String modulusHex, String exponentHex) {
    try {
      final modulus = BigInt.parse(modulusHex, radix: 16);
      final exponent = BigInt.parse(exponentHex, radix: 16);
      final modulusWords = (modulusHex.length / 4).ceil();
      final rawChunkSize = 2 * (modulusWords - 1);
      final chunkSize = rawChunkSize < 2 ? 2 : rawChunkSize;
      final codeUnits = password.split('').reversed.join().codeUnits.toList();

      while (codeUnits.length % chunkSize != 0) {
        codeUnits.add(0);
      }

      final blocks = <String>[];
      for (var start = 0; start < codeUnits.length; start += chunkSize) {
        var block = BigInt.zero;
        var digit = 0;
        for (var offset = 0; offset < chunkSize; offset += 2) {
          final low = codeUnits[start + offset];
          final high = start + offset + 1 < codeUnits.length
              ? codeUnits[start + offset + 1]
              : 0;
          block += BigInt.from(low + (high << 8)) << (16 * digit);
          digit++;
        }

        var encrypted = block.modPow(exponent, modulus).toRadixString(16);
        encrypted = encrypted.padLeft(((encrypted.length + 3) ~/ 4) * 4, '0');
        blocks.add(encrypted);
      }

      return blocks.join(' ');
    } catch (_) {
      return password;
    }
  }
}

class LoginResult {
  final bool success;
  final String userId;
  final String userName;
  final String? cookie;
  final String? ticket;
  final String? libraryJwt;

  LoginResult({
    required this.success,
    required this.userId,
    required this.userName,
    this.cookie,
    this.ticket,
    this.libraryJwt,
  });
}

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

class _LibraryServiceCandidate {
  final String label;
  final String url;

  const _LibraryServiceCandidate(this.label, this.url);
}

class _LibraryGatewayResult {
  final int statusCode;
  final String cookies;
  final String location;

  const _LibraryGatewayResult({
    required this.statusCode,
    required this.cookies,
    required this.location,
  });
}

class _LibraryServiceTicketResult {
  final int statusCode;
  final String location;
  final String ticket;

  const _LibraryServiceTicketResult({
    required this.statusCode,
    required this.location,
    required this.ticket,
  });
}

class _LibraryCallbackResult {
  final int statusCode;
  final String cookies;
  final String location;
  final List<String> redirects;
  final dynamic data;

  const _LibraryCallbackResult({
    required this.statusCode,
    required this.cookies,
    required this.location,
    required this.redirects,
    required this.data,
  });
}
