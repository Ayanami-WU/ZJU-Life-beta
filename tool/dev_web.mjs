#!/usr/bin/env node

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const toolDir = path.join(rootDir, 'tool');
const isWindows = process.platform === 'win32';

const flutterBinary = path.resolve(
  rootDir,
  '..',
  'flutter',
  'bin',
  isWindows ? 'flutter.bat' : 'flutter',
);
const proxyScript = path.join(toolDir, 'library_proxy.mjs');

if (!fs.existsSync(flutterBinary)) {
  console.error(`Flutter binary not found at ${flutterBinary}`);
  process.exit(1);
}

const proxyPort = process.env.LIBRARY_PROXY_PORT || '51989';
const webPort = process.env.WEB_PORT || '8765';
const childEnv = {
  ...process.env,
  LIBRARY_PROXY_PORT: proxyPort,
  LIBRARY_PROXY_URL:
    process.env.LIBRARY_PROXY_URL || `http://127.0.0.1:${proxyPort}`,
  CANTEEN_PROXY_URL:
    process.env.CANTEEN_PROXY_URL ||
    `http://127.0.0.1:${proxyPort}/canteen/general_new.php`,
};

const flutterArgs = process.argv.slice(2);
if (flutterArgs.length == 0) {
  flutterArgs.push(
    'run',
    '-d',
    'web-server',
    '--web-hostname',
    '127.0.0.1',
    '--web-port',
    webPort,
  );
}

let shuttingDown = false;
let exitCode = 0;

const proxyProcess = spawn(process.execPath, [proxyScript], {
  cwd: rootDir,
  env: childEnv,
  stdio: 'inherit',
});

const flutterProcess = spawn(flutterBinary, flutterArgs, {
  cwd: rootDir,
  env: childEnv,
  stdio: 'inherit',
});

function terminateChild(child, signal = 'SIGTERM') {
  if (!child || child.exitCode !== null || child.killed) {
    return;
  }

  try {
    child.kill(signal);
  } catch {
    // Ignore shutdown races.
  }
}

function shutdown(code = 0) {
  if (shuttingDown) {
    return;
  }

  shuttingDown = true;
  exitCode = code;
  terminateChild(flutterProcess, 'SIGINT');
  terminateChild(proxyProcess, 'SIGINT');
}

for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) {
  process.on(signal, () => shutdown(0));
}

proxyProcess.on('exit', (code, signal) => {
  if (shuttingDown) {
    return;
  }

  if (code !== 0) {
    console.error(
      `library_proxy.mjs exited unexpectedly (${signal || `code ${code}`})`,
    );
  }
  shutdown(code ?? 1);
});

flutterProcess.on('exit', (code) => {
  shutdown(code ?? 0);
});

process.on('exit', () => {
  terminateChild(flutterProcess, 'SIGTERM');
  terminateChild(proxyProcess, 'SIGTERM');
});

const waitForChildren = Promise.allSettled([
  new Promise((resolve) => proxyProcess.on('close', resolve)),
  new Promise((resolve) => flutterProcess.on('close', resolve)),
]);

await waitForChildren;
process.exit(exitCode);
