@echo off
cd /d "%~dp0"
title Caderno Infinito - Copiar configuracao OAuth anterior
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$source=Join-Path $env:USERPROFILE 'ci';$dest='%~dp0';if(-not (Test-Path $source)){Write-Host 'Pasta antiga ci nao encontrada.';exit 1};foreach($n in @('config.local.json','oauth_web.json','oauth_desktop.json','google-services.json')){$from=Join-Path $source $n;$to=Join-Path $dest $n;if((Test-Path $from) -and -not (Test-Path $to)){Copy-Item -LiteralPath $from -Destination $to;Write-Host ('Copiado: '+$n)}};Write-Host 'Somente arquivos de configuracao ausentes foram copiados. Nao compartilhe esses arquivos.'"
pause
