param(
  [string]$WebClientJson = '',
  [string]$AndroidServicesJson = '',
  [string]$DesktopClientJson = ''
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Get-ExistingFile([string]$preferred, [string[]]$candidates) {
  if ($preferred) {
    if (-not (Test-Path -LiteralPath $preferred)) { throw "Arquivo não encontrado: $preferred" }
    return (Resolve-Path -LiteralPath $preferred).Path
  }
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {return (Resolve-Path -LiteralPath $candidate).Path}
  }
  return $null
}
function Assert-ClientId([string]$value, [string]$where) {
  if ($value -notmatch '^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$') {
    throw "Client ID OAuth inválido em $where"
  }
}
function Read-Json([string]$path) {
  return (Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json)
}

# Ambos podem ser obtidos no Google Cloud. A pasta e os desenhos não são lidos aqui.
$settings = [ordered]@{
  GOOGLE_WEB_CLIENT_ID = ''
  GOOGLE_DESKTOP_CLIENT_ID = ''
  GOOGLE_DESKTOP_CLIENT_SECRET = ''
}
if (Test-Path 'config.local.json') {
  $current = Read-Json 'config.local.json'
  foreach ($key in @($settings.Keys)) {
    if ($null -ne $current.$key -and ($current.$key -notlike 'COLE_AQUI*')) {
      $settings[$key] = [string]$current.$key
    }
  }
}

$webFile = Get-ExistingFile $WebClientJson @('oauth_web.json', 'web_oauth.json')
$servicesFile = Get-ExistingFile $AndroidServicesJson @('google-services.json', 'android/app/google-services.json')
$desktopFile = Get-ExistingFile $DesktopClientJson @('oauth_desktop.json', 'desktop_oauth.json')

if ($webFile) {
  $j = Read-Json $webFile
  if (-not $j.web) { throw "O arquivo $webFile não contém 'web': baixe um cliente OAuth do tipo Aplicativo Web." }
  $id = [string]$j.web.client_id
  Assert-ClientId $id $webFile
  $settings['GOOGLE_WEB_CLIENT_ID'] = $id
} elseif ($servicesFile) {
  $j = Read-Json $servicesFile
  $ids = @()
  foreach ($client in @($j.client)) {
    foreach ($oauth in @($client.oauth_client)) {
      if ($oauth.client_type -eq 3) { $ids += [string]$oauth.client_id }
    }
  }
  $ids = @($ids | Sort-Object -Unique | Where-Object { $_ })
  if ($ids.Count -ne 1) {
    throw "No google-services.json, esperado um único Web Client ID (client_type=3); encontrados: $($ids.Count)."
  }
  Assert-ClientId $ids[0] $servicesFile
  $settings['GOOGLE_WEB_CLIENT_ID'] = $ids[0]
}

if ($desktopFile) {
  $j = Read-Json $desktopFile
  if (-not $j.installed) { throw "O arquivo $desktopFile não contém 'installed': use um cliente OAuth de Desktop." }
  $id = [string]$j.installed.client_id
  Assert-ClientId $id $desktopFile
  $settings['GOOGLE_DESKTOP_CLIENT_ID'] = $id
  $settings['GOOGLE_DESKTOP_CLIENT_SECRET'] = [string]$j.installed.client_secret
}

$jsonText = $settings | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'config.local.json'), $jsonText, (New-Object System.Text.UTF8Encoding($false)))
if ($settings['GOOGLE_WEB_CLIENT_ID']) {
  Write-Host 'Android: Web Client ID carregado automaticamente para a compilação.' -ForegroundColor Green
} else {
  Write-Warning 'Android: sem Web Client ID. Login Google não funcionará até configurar OAuth antes de compilar. Use -WebClientJson ou google-services.json.'
}
if ($settings['GOOGLE_DESKTOP_CLIENT_ID']) {
  Write-Host 'Windows: configuração OAuth do aplicativo carregada para o build.' -ForegroundColor Green
} else {
  Write-Host 'Windows: o usuário poderá importar o JSON OAuth Desktop ao clicar em Entrar com Google.' -ForegroundColor Cyan
}
Write-Host 'Nenhuma senha de conta Google foi solicitada ou armazenada neste script.'
