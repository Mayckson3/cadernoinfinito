param(
  [ValidateSet('ambos','windows','apk','check')]
  [string]$Target = 'ambos'
)
$ErrorActionPreference = 'Stop'
$source = $PSScriptRoot
$destination = Join-Path $env:USERPROFILE 'ci108_full'
function Check-Exit([string]$what) {
  if ($LASTEXITCODE -ne 0) {throw "$what falhou (codigo $LASTEXITCODE)."}
}
try {
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter nao foi encontrado no PATH. Verifique flutter --version no PowerShell.'
  }
  if (-not [string]::Equals($source, $destination, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "Copiando o projeto completo para $destination" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $exclude = @('build','.dart_tool','dist','.gradle','ephemeral','.plugin_symlinks')
    & robocopy.exe $source $destination /E /XJ /XD @exclude /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { throw "Falha ao copiar arquivos (robocopy $LASTEXITCODE)." }
  }
  Set-Location $destination
  if (-not (Test-Path 'pubspec.yaml')) {throw 'pubspec.yaml nao encontrado na pasta local.'}
  if (-not (Test-Path 'build.ps1')) {throw 'build.ps1 nao encontrado na pasta local.'}
  Write-Host "Projeto local: $destination" -ForegroundColor Cyan
  Write-Host "Build: $Target" -ForegroundColor Cyan
  & (Join-Path $destination 'build.ps1') -Target $Target
  Check-Exit 'Compilacao'
  Write-Host 'PROCESSO CONCLUIDO.' -ForegroundColor Green
  if ($Target -ne 'check' -and (Test-Path (Join-Path $destination 'dist'))) {
    Start-Process explorer.exe -ArgumentList ('"' + (Join-Path $destination 'dist') + '"')
  }
  exit 0
} catch {
  Write-Host ('ERRO: ' + $_.Exception.Message) -ForegroundColor Red
  Write-Host 'A pasta anterior nao foi apagada. Copie a mensagem acima para o diagnostico.' -ForegroundColor Yellow
  exit 1
}
