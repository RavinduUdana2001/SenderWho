#!/usr/bin/env node

const { spawn } = require('node:child_process');
const { existsSync } = require('node:fs');

const nodeArgs = process.argv.slice(2);
const entryIndex = nodeArgs.findIndex((argument) => !argument.startsWith('-'));
const entryPath = nodeArgs[entryIndex];

if (entryIndex === -1 || !entryPath) {
  console.error('Missing compiled application entry path.');
  process.exit(1);
}

// Nest CLI currently launches an extensionless path (for example dist/main).
// Node 26 requires the .js suffix for a CommonJS command-line entry point.
const resolvedEntry = existsSync(entryPath) ? entryPath : `${entryPath}.js`;
nodeArgs[entryIndex] = resolvedEntry;

const child = spawn(process.execPath, nodeArgs, {
  stdio: 'inherit',
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => child.kill(signal));
}

child.on('error', (error) => {
  console.error(error);
  process.exit(1);
});

child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }

  process.exit(code ?? 1);
});
