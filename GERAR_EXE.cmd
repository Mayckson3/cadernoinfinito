@echo off
cd /d "%~dp0"
title Caderno Infinito - Gerar Windows EXE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Target windows
if errorlevel 1 (echo ERRO: confira a mensagem acima.) else (explorer "%~dp0dist\CadernoInfinito_Windows")
pause
