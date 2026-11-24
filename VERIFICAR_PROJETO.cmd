@echo off
cd /d "%~dp0"
title Caderno Infinito - Analisar e executar testes
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Target check
pause
