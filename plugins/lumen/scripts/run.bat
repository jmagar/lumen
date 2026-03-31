@echo off
setlocal enabledelayedexpansion

set "PLUGIN_ROOT=%~dp0.."

set "ARCH=amd64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"

if not defined LUMEN_BACKEND set "LUMEN_BACKEND=ollama"
if not defined LUMEN_EMBED_MODEL set "LUMEN_EMBED_MODEL=ordis/jina-embeddings-v2-base-code"

set "BINARY=%PLUGIN_ROOT%\bin\lumen-windows-%ARCH%.exe"

if not exist "%BINARY%" (
  set "REPO=ory/lumen"
  set "MANIFEST=%PLUGIN_ROOT%\.codex-plugin\plugin.json"
  if not exist "!MANIFEST!" (
    echo Error: .codex-plugin\plugin.json not found in %PLUGIN_ROOT% >&2
    exit /b 1
  )

  for /f "tokens=2 delims=:" %%j in ('findstr /r /c:"\"version\"" "!MANIFEST!"') do (
    set "VERSION=v%%~j"
    set "VERSION=!VERSION: =!"
    set "VERSION=!VERSION:,=!"
    set "VERSION=!VERSION:"=!"
  )

  if "!VERSION!"=="" (
    echo Error: could not read version from !MANIFEST! >&2
    exit /b 1
  )

  set "ASSET=lumen-!VERSION:~1!-windows-!ARCH!.exe"
  set "URL=https://github.com/!REPO!/releases/download/!VERSION!/!ASSET!"

  echo Downloading lumen !VERSION! for windows/!ARCH!... >&2
  if not exist "%PLUGIN_ROOT%\bin" mkdir "%PLUGIN_ROOT%\bin"
  curl -sfL "!URL!" -o "%BINARY%"
  echo Installed lumen to %BINARY% >&2
)

"%BINARY%" %*
