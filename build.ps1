param(
  [ValidateSet('windows','apk','ambos','run-windows','run-android','test','analyze','check')]
  [string]$Target='ambos',
  [switch]$RequireEmbeddedGoogleId
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Assert-Success([string]$description) {
  if ($LASTEXITCODE -ne 0) { throw "$description falhou (codigo $LASTEXITCODE)." }
}
function Ensure-Plataforms {
  $missingWindows = -not (Test-Path 'windows/runner/main.cpp')
  $missingAndroid = -not (Test-Path 'android/app/build.gradle.kts')
  if ($missingWindows -or $missingAndroid) {
    Write-Host 'Preparando as pastas nativas Windows/Android (apenas na primeira compilacao)...' -ForegroundColor Cyan
    & flutter create --platforms=android,windows --org br.cadernonuvem .
    Assert-Success 'flutter create'
    $script:CreatedNative = $true
  }
  $manifest = 'android/app/src/main/AndroidManifest.xml'
  if ((Test-Path $manifest)) {
    $content = Get-Content $manifest -Raw -Encoding UTF8
    if ($content -notmatch 'android.permission.INTERNET') {
      $content = [regex]::Replace($content,'(<manifest[^>]*>)', '$1' + "`r`n    <uses-permission android:name=`"android.permission.INTERNET`"/>",1)
      [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot $manifest), $content, [System.Text.UTF8Encoding]::new($false))
    }
  }
}
function Prepare-Configuration {
  & (Join-Path $PSScriptRoot 'prepare_google_login.ps1')
  if ($LASTEXITCODE -ne 0) {throw 'Nao foi possivel preparar o login Google.'}
  if (-not (Test-Path 'config.local.json')) { throw 'config.local.json nao foi gerado.' }
}
function Test-AndroidClientId {
  $auth = Get-Content 'config.local.json' -Raw -Encoding UTF8 | ConvertFrom-Json
  $id = [string]$auth.GOOGLE_WEB_CLIENT_ID
  if ($id -notmatch '^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$') {
    if ($RequireEmbeddedGoogleId) {throw 'Para embutir o login Google, adicione oauth_web.json ao projeto e compile novamente.'}
    Write-Warning 'Sem OAuth Web na compilacao. O login Android precisara importar o JSON OAuth Web no primeiro uso; o cliente Android com SHA-1 tambem deve existir no Google Cloud.'
  }
}
function Export-Result([string]$platform) {
  New-Item -ItemType Directory -Path 'dist' -Force | Out-Null
  if ($platform -eq 'windows') {
    $release = 'build/windows/x64/runner/Release'
    if (-not (Test-Path "$release/caderno_infinito.exe")) {throw 'EXE nao encontrado no resultado do Flutter.'}
    $destination = Join-Path $PSScriptRoot 'dist/CadernoInfinito_Windows'
    if (Test-Path $destination) {Remove-Item $destination -Recurse -Force}
    Copy-Item $release $destination -Recurse
    Write-Host "Windows: $destination\caderno_infinito.exe" -ForegroundColor Green
    Write-Host 'Distribua a pasta Windows completa, incluindo DLLs e data.'
  } else {
    $apk = 'build/app/outputs/flutter-apk/app-release.apk'
    if (-not (Test-Path $apk)) {throw 'APK nao encontrado no resultado do Flutter.'}
    $destination=Join-Path $PSScriptRoot 'dist/CadernoInfinito_Android.apk'
    Copy-Item $apk $destination -Force
    Write-Host "Android: $destination" -ForegroundColor Green
  }
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter nao encontrado. Verifique Flutter SDK no PATH e execute flutter doctor.'
}
if ($PSScriptRoot.Length -gt 90) {
  Write-Warning "Pasta extensa ($($PSScriptRoot.Length) caracteres). No Windows, recomendamos extrair o projeto em $env:USERPROFILE\ci108_full para evitar erros C1083 do compilador C++."
}
if ($Target -in @('windows','apk','ambos','run-windows','run-android')) {
  Ensure-Plataforms
  & flutter pub get
  Assert-Success 'flutter pub get'
  Prepare-Configuration
  if ($Target -in @('apk','ambos','run-android')) {Test-AndroidClientId}
  if ($script:CreatedNative -and $Target -in @('windows','ambos','run-windows')) {
    Write-Host 'Configurando PDFium para Windows...' -ForegroundColor Cyan
    & dart run pdfx:install_windows
    if ($LASTEXITCODE -ne 0) { Write-Warning 'PDFium precisa ser conferido se a compilacao Windows apontar problema de CMake.' }
  }
}
$defines=@('--dart-define-from-file=config.local.json')
switch($Target) {
  'windows' {
    & flutter build windows --release @defines
    Assert-Success 'Build Windows'
    Export-Result 'windows'
  }
  'apk' {
    & flutter build apk --release @defines
    Assert-Success 'Build Android'
    Export-Result 'apk'
  }
  'ambos' {
    & flutter build windows --release @defines
    Assert-Success 'Build Windows'
    Export-Result 'windows'
    & flutter build apk --release @defines
    Assert-Success 'Build Android'
    Export-Result 'apk'
  }
  'run-windows' { & flutter run -d windows @defines; Assert-Success 'Rodar Windows' }
  'run-android' { & flutter run -d android @defines; Assert-Success 'Rodar Android' }
  'test' { & flutter test; Assert-Success 'Testes' }
  'analyze' { & flutter analyze; Assert-Success 'Analise' }
  'check' {
    & flutter pub get; Assert-Success 'Dependencias'
    & flutter analyze; Assert-Success 'Analise'
    & flutter test; Assert-Success 'Testes'
  }
}
Write-Host "Concluido: $Target" -ForegroundColor Green
