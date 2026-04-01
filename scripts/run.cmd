: << 'CMDBLOCK'
@echo off
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%run.bat" %*
exit /b %ERRORLEVEL%
CMDBLOCK

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${SCRIPT_DIR}/run.sh" "$@"
