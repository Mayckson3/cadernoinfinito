@echo off
cd /d "%~dp0"
title Caderno Infinito - Gerar Android APK
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Target apk
if errorlevel 1 (echo ERRO: confira a mensagem acima.) else (explorer "%~dp0dist")
pause
