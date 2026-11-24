@echo off
if exist "%~dp0dist" (
  explorer "%~dp0dist"
) else (
  echo Ainda nao foi feita a compilacao. Execute GERAR_EXE.cmd, GERAR_APK.cmd ou COMPILAR_TUDO.cmd.
  pause
)
