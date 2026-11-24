@echo off
cd /d "%~dp0"
title Caderno Infinito - Gerar EXE e APK
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Target ambos
if errorlevel 1 (
  echo.
  echo ERRO: copie a mensagem acima para diagnostico.
) else (
  echo.
  echo Pronto! Os arquivos estao na pasta dist.
  explorer "%~dp0dist"
)
pause
