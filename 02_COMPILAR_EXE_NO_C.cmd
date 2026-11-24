@echo off
setlocal
title Caderno Infinito - Compilar EXE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0COMPILAR_NO_C.ps1" -Target windows
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" (
  echo.
  echo Copie as mensagens de erro mostradas acima.
)
echo.
pause
exit /b %RESULT%
