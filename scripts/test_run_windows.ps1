#!/usr/bin/env pwsh
# End-to-end test for run.bat on Windows, mirroring the POSIX MCP handshake
# test in test_run.sh. Exercises the first-install code path: no binary in
# bin/, a stub curl.bat shadows real curl via PATH, the "download" copies a
# cross-compiled mock MCP server into place, and a real JSON-RPC initialize
# request is piped into `run.bat stdio` with the response asserted.
#
# Passing proves run.bat did not fast-exit in stdio mode, reached the
# download path, wrote the artefact where it would exec it, and invoked
# it with stdin/stdout inherited correctly.

$ErrorActionPreference = 'Stop'

$PASS = 0
$FAIL = 0

function Pass($msg) { Write-Host "  PASS: $msg"; $script:PASS++ }
function Fail($msg) { Write-Host "  FAIL: $msg"; $script:FAIL++ }

Write-Host "=== stdio first-install MCP handshake test (run.bat) ==="

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = (Resolve-Path (Join-Path $ScriptDir '..')).Path

$TmpRoot     = (New-Item -ItemType Directory -Path (Join-Path $env:TEMP "lumen-stdio-$([guid]::NewGuid().ToString('N'))")).FullName
$FakeCurlDir = (New-Item -ItemType Directory -Path (Join-Path $env:TEMP "fakecurl-$([guid]::NewGuid().ToString('N'))")).FullName
$MockBinDir  = (New-Item -ItemType Directory -Path (Join-Path $env:TEMP "mockbin-$([guid]::NewGuid().ToString('N'))")).FullName

$origPath = $env:PATH

try {
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $expectedBinary = Join-Path $TmpRoot "bin\lumen-windows-$arch.exe"

    # Build the mock MCP server — pure Go, no CGO.
    $mockBin = Join-Path $MockBinDir 'mock_lumen.exe'
    $env:CGO_ENABLED = '0'
    Push-Location $RepoRoot
    try {
        $buildOutput = & go build -o $mockBin ./scripts/testdata/mock_mcp_server 2>&1
        if ($LASTEXITCODE -ne 0) {
            Fail "could not build mock MCP server (exit $LASTEXITCODE)"
            $buildOutput | ForEach-Object { Write-Host "          $_" }
            return
        }
    } finally {
        Pop-Location
    }

    # Minimal plugin root: manifest only.
    $manifest = '{' + "`n" + '  ".": "0.0.1"' + "`n" + '}' + "`n"
    [IO.File]::WriteAllText((Join-Path $TmpRoot '.release-please-manifest.json'), $manifest, [Text.Encoding]::ASCII)
    New-Item -ItemType Directory -Path (Join-Path $TmpRoot 'bin') | Out-Null

    # Stub curl: curl.bat parses -o <target> and copies the prebuilt mock in.
    # cmd.exe's PATHEXT search is per-directory: our fake dir is prepended
    # to PATH and contains only curl.bat, so it wins over C:\Windows\System32
    # regardless of PATHEXT ordering.
    $curlStub = @'
@echo off
setlocal enabledelayedexpansion
:loop
if "%~1"=="" goto done
if "%~1"=="-o" (
  copy /Y "%LUMEN_MOCK_BINARY%" "%~2" >nul
  shift
  shift
  goto loop
)
shift
goto loop
:done
exit /b 0
'@
    [IO.File]::WriteAllText((Join-Path $FakeCurlDir 'curl.bat'), $curlStub, [Text.Encoding]::ASCII)

    # Write the MCP initialize request (LF-terminated) to a stdin file.
    $initReq = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"launcher-e2e","version":"1.0"}}}'
    $stdinFile  = Join-Path $TmpRoot 'stdin.txt'
    $stdoutFile = Join-Path $TmpRoot 'stdout.txt'
    $stderrFile = Join-Path $TmpRoot 'stderr.txt'
    [IO.File]::WriteAllText($stdinFile, $initReq + "`n", [Text.Encoding]::ASCII)

    $env:CLAUDE_PLUGIN_ROOT = $TmpRoot
    $env:LUMEN_MOCK_BINARY  = $mockBin
    $env:PATH = "$FakeCurlDir;$origPath"

    $runBat = Join-Path $ScriptDir 'run.bat'
    $proc = Start-Process -FilePath cmd.exe `
        -ArgumentList '/c', "`"$runBat`" stdio" `
        -RedirectStandardInput  $stdinFile `
        -RedirectStandardOutput $stdoutFile `
        -RedirectStandardError  $stderrFile `
        -NoNewWindow -Wait -PassThru

    $exitCode = $proc.ExitCode

    if ($exitCode -ne 0) {
        Fail "run.bat stdio exited $exitCode — MCP server would be dead for the session"
        Write-Host "        stderr:"
        if (Test-Path $stderrFile) { Get-Content $stderrFile | ForEach-Object { Write-Host "          $_" } }
        return
    }
    if (-not (Test-Path $expectedBinary)) {
        Fail "run.bat stdio did not place artefact at $expectedBinary"
        return
    }
    $stdout = if (Test-Path $stdoutFile) { Get-Content $stdoutFile -Raw } else { '' }
    if ($stdout -notmatch '"jsonrpc":"2\.0"') {
        Fail "MCP initialize produced no JSON-RPC 2.0 response on stdout"
        Write-Host "        stdout:"
        ($stdout -split "`n") | ForEach-Object { Write-Host "          $_" }
        return
    }
    if ($stdout -notmatch '"name":"mock-lumen"') {
        Fail "MCP response did not come from the exec'd mock — run.bat may be swallowing stdout"
        Write-Host "        stdout:"
        ($stdout -split "`n") | ForEach-Object { Write-Host "          $_" }
        return
    }
    Pass "run.bat stdio downloads, execs, and brokers MCP initialize on first install"
} finally {
    $env:PATH = $origPath
    Remove-Item -Recurse -Force $TmpRoot, $FakeCurlDir, $MockBinDir -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '=== summary ==='
Write-Host "  passed: $PASS"
Write-Host "  failed: $FAIL"
if ($FAIL -gt 0) { exit 1 }
exit 0
