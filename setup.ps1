$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
Write-Host 'Caderno Infinito - criação das pastas Android e Windows' -ForegroundColor Cyan
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter não encontrado. Instale Flutter SDK, adicione ao PATH e execute flutter doctor.' }
flutter create --platforms=android,windows --org br.cadernonuvem .
if ($LASTEXITCODE -ne 0) { throw 'flutter create falhou' }
$manifest = Join-Path $PSScriptRoot 'android/app/src/main/AndroidManifest.xml'
if ((Test-Path $manifest)) {
  $xml = Get-Content $manifest -Raw
  if ($xml -notmatch 'android.permission.INTERNET') {
    $replacement = '$1' + "`r`n    <uses-permission android:name=`"android.permission.INTERNET`"/>"
    $xml = [regex]::Replace($xml, '(<manifest[^>]*>)', $replacement, 1)
    Set-Content -Path $manifest -Value $xml -Encoding utf8
  }
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get falhou' }
dart run pdfx:install_windows
if ($LASTEXITCODE -ne 0) { Write-Warning 'Verifique o PDFium/arquivo windows/CMakeLists.txt antes de compilar para Windows.' }
& (Join-Path $PSScriptRoot 'prepare_google_login.ps1')
Write-Host 'Projeto preparado. No uso normal, toque em Entrar com Google.' -ForegroundColor Green
