@echo off
setlocal
title Caderno Infinito - Compilar EXE e APK
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0COMPILAR_NO_C.ps1" -Target ambos
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" (
  echo.
  echo Copie as mensagens de erro mostradas acima.
)
echo.
pause
exit /b %RESULT%
