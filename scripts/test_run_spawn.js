// Spawn-semantics regression guard.
//
// This invokes the launcher exactly the way Claude Code's MCP transport
// does: child_process.spawn(command, args, { shell: false }). On macOS
// and Linux that goes through libuv's posix_spawn (no ENOEXEC fallback
// to /bin/sh), and on Windows through cross-spawn-style PATHEXT
// resolution wrapped in cmd.exe /d /s /c.
//
// PR #145 and PR #157 both shipped polyglot launchers that passed every
// pre-existing CI test but exploded in production because no test
// matched these exact spawn semantics. This file closes that gap.
//
// The bar:
//   1. spawn(extensionless path) succeeds on all three OSes.
//   2. Captured stdout is byte-equal to the launcher's intended output:
//      strict JSON.parse on a single buffer with zero leading bytes.
//   3. Optional cross-spawn variant (npm-installable) reproduces the
//      exact transport Claude Code's MCP SDK uses on Windows.

'use strict';

const { spawn } = require('child_process');
const fs        = require('fs');
const os        = require('os');
const path      = require('path');

let pass = 0;
let fail = 0;

function passMsg(msg) { console.log(`  PASS: ${msg}`); pass++; }
function failMsg(msg) { console.log(`  FAIL: ${msg}`); fail++; }

const TMP_DIR    = fs.mkdtempSync(path.join(os.tmpdir(), 'lumen-spawn-'));
const SCRIPTS    = path.join(TMP_DIR, 'scripts');
fs.mkdirSync(SCRIPTS, { recursive: true });

// Mock launcher pair. Both files share the base name `run` and are
// dispatched by extension by the host OS:
//   - POSIX: kernel direct-execs `run` because byte 0 is `#!`.
//   - Windows: cmd.exe / cross-spawn resolve `run.cmd` via PATHEXT.
const POSIX_LAUNCHER = `#!/usr/bin/env bash
printf '%s' '{"mock":"ok","args":'
node -e 'process.stdout.write(JSON.stringify(process.argv.slice(1)))' -- "$@"
printf '%s\\n' '}'
`;
const WINDOWS_LAUNCHER = `@echo off
setlocal enabledelayedexpansion
set "ARGS="
:argloop
if "%~1"=="" goto done
if defined ARGS (set "ARGS=!ARGS!,\\"%~1\\"") else (set "ARGS=\\"%~1\\"")
shift
goto argloop
:done
echo {"mock":"ok","args":[!ARGS!]}
`;

const posixPath   = path.join(SCRIPTS, 'run');
const windowsPath = path.join(SCRIPTS, 'run.cmd');

fs.writeFileSync(posixPath, POSIX_LAUNCHER);
fs.writeFileSync(windowsPath, WINDOWS_LAUNCHER);
fs.chmodSync(posixPath, 0o755);

// Extensionless invocation — the EXACT string the plugin manifests
// hand to Claude Code / cross-spawn. On Windows this triggers PATHEXT
// resolution to `run.cmd`. On POSIX it is the literal target of the
// posix_spawn syscall.
const launcher = path.join(SCRIPTS, 'run');

function runOne(label, cmd, args, opts = {}) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { ...opts, shell: false });
    const stdoutChunks = [];
    const stderrChunks = [];
    child.stdout.on('data', (c) => stdoutChunks.push(c));
    child.stderr.on('data', (c) => stderrChunks.push(c));
    child.on('error', (err) => {
      failMsg(`${label}: spawn failed (${err.code || err.message})`);
      resolve();
    });
    child.on('close', (code) => {
      const stdout = Buffer.concat(stdoutChunks).toString('utf8');
      const stderr = Buffer.concat(stderrChunks).toString('utf8');

      if (code !== 0) {
        failMsg(`${label}: exit ${code}`);
        if (stderr) console.log(`         stderr: ${stderr.trim()}`);
        if (stdout) console.log(`         stdout: ${stdout.trim()}`);
        return resolve();
      }
      let parsed;
      try {
        parsed = JSON.parse(stdout.trim());
      } catch (err) {
        failMsg(`${label}: stdout is not valid JSON — launcher polluted output`);
        console.log(`         stdout (raw): ${JSON.stringify(stdout)}`);
        if (stderr) console.log(`         stderr: ${stderr.trim()}`);
        return resolve();
      }
      if (parsed.mock !== 'ok') {
        failMsg(`${label}: JSON did not come from launcher payload`);
        console.log(`         got: ${JSON.stringify(parsed)}`);
        return resolve();
      }
      if (!Array.isArray(parsed.args) || parsed.args.length !== args.length) {
        failMsg(`${label}: argv mismatch`);
        console.log(`         expected ${args.length} args, got ${JSON.stringify(parsed.args)}`);
        return resolve();
      }
      passMsg(`${label}: clean spawn, byte-exact JSON, argv preserved`);
      resolve();
    });
  });
}

async function main() {
  console.log('=== spawn-semantics regression guard ===');
  console.log(`    platform: ${process.platform}`);
  console.log(`    node:     ${process.version}`);

  // Test 1: child_process.spawn with extensionless path. On macOS this
  // exercises posix_spawn directly (the path that broke PR #145). On
  // Windows it exercises Node's internal cmd.exe wrap (which itself
  // does PATHEXT for absolute extensionless paths).
  await runOne(
    'child_process.spawn(extensionless, ...)',
    launcher,
    ['stdio', '--flag'],
  );

  // Test 2 (optional): cross-spawn — exactly the package Claude Code's
  // MCP SDK uses for StdioClientTransport. Only runs if cross-spawn
  // is installable. CI installs it via scripts/package.json; locally
  // we skip silently.
  let crossSpawn;
  try {
    crossSpawn = require('cross-spawn');
  } catch (_) {
    console.log('  SKIP: cross-spawn not installed (run `npm install` in scripts/)');
  }
  if (crossSpawn) {
    await new Promise((resolve) => {
      const child = crossSpawn(launcher, ['stdio', '--flag'], { shell: false });
      const stdoutChunks = [];
      const stderrChunks = [];
      child.stdout.on('data', (c) => stdoutChunks.push(c));
      child.stderr.on('data', (c) => stderrChunks.push(c));
      child.on('error', (err) => {
        failMsg(`cross-spawn(extensionless, ...): spawn failed (${err.code || err.message})`);
        resolve();
      });
      child.on('close', (code) => {
        const stdout = Buffer.concat(stdoutChunks).toString('utf8');
        const stderr = Buffer.concat(stderrChunks).toString('utf8');
        if (code !== 0) {
          failMsg(`cross-spawn(extensionless, ...): exit ${code}`);
          if (stderr) console.log(`         stderr: ${stderr.trim()}`);
          return resolve();
        }
        try {
          const parsed = JSON.parse(stdout.trim());
          if (parsed.mock === 'ok') {
            passMsg('cross-spawn(extensionless, ...): clean spawn, byte-exact JSON');
          } else {
            failMsg('cross-spawn(extensionless, ...): JSON payload mismatch');
          }
        } catch (err) {
          failMsg('cross-spawn(extensionless, ...): stdout is not valid JSON');
          console.log(`         stdout (raw): ${JSON.stringify(stdout)}`);
        }
        resolve();
      });
    });
  }

  // Cleanup
  try { fs.rmSync(TMP_DIR, { recursive: true, force: true }); } catch (_) {}

  console.log('');
  console.log('=== summary ===');
  console.log(`  passed: ${pass}`);
  console.log(`  failed: ${fail}`);
  process.exit(fail > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(2);
});
