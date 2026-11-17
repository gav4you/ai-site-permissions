<#
.SYNOPSIS
  Set every Chromium site setting to Allow for chosen sites, in every profile of every installed Chromium browser.

.DESCRIPTION
  Writes per-site exceptions into each profile's Preferences file (profile.content_settings.exceptions),
  so they show up as "Allow" in Settings > Privacy and security > Site settings - exactly as if you had
  clicked each one by hand. Device-chooser permissions (USB, serial, HID, Bluetooth, file editing) only
  accept Ask or Block in Chrome, so they are set to Ask (the most permissive value).

  Browsers MUST be fully closed: Chromium rewrites Preferences from memory on exit and would undo the edit.
  Every Preferences file is backed up as Preferences.bak-<timestamp> before it is changed.

.PARAMETER Sites
  Hostnames, e.g. claude.ai, chatgpt.com. Presets: claude, chatgpt, gemini, ai (all three).
.PARAMETER Subdomains
  Also cover every subdomain of each site ([*.]host).
.PARAMETER Browsers
  Any of: chrome, edge, brave, vivaldi, chromium. Default: all that are installed.
.PARAMETER CloseBrowsers
  Close the target browsers first (asks nothing - get the user's OK before passing this).
.PARAMETER Remove
  Remove the exceptions this script adds for the given sites instead of adding them.
.PARAMETER WhatIf
  Show which profiles would change, without writing.

.EXAMPLE
  pwsh ./allow-site-permissions.ps1 -Sites ai -Subdomains -CloseBrowsers
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string[]]$Sites,
  [switch]$Subdomains,
  [string[]]$Browsers = @('chrome','edge','brave','vivaldi','chromium'),
  [switch]$CloseBrowsers,
  [switch]$Remove,
  [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'

$presets = @{
  claude  = @('claude.ai','clau.de')
  chatgpt = @('chatgpt.com','chat.openai.com')
  gemini  = @('gemini.google.com')
}
$presets.ai = $presets.claude + $presets.chatgpt + $presets.gemini
$hosts = @(foreach ($s in $Sites) { if ($presets.ContainsKey($s.ToLower())) { $presets[$s.ToLower()] } else { $s -replace '^https?://','' -replace '/.*$','' } }) | Select-Object -Unique

$patterns = @(foreach ($h in $hosts) { "https://${h}:443,*"; if ($Subdomains) { "https://[*.]$h,*" } })

# 1 = Allow
$allow = @(
  'geolocation','notifications','media_stream_camera','media_stream_mic','camera_pan_tilt_zoom','sensors',
  'midi_sysex','clipboard','payment_handler','popups','automatic_downloads','javascript','javascript_jit',
  'javascript_optimizer','images','sound','cookies','background_sync','idle_detection','window_placement',
  'local_fonts','protected_media_identifier','ar','vr','hand_tracking','auto_picture_in_picture',
  'automatic_fullscreen','keyboard_lock','pointer_lock','captured_surface_control','storage_access',
  'top_level_storage_access','mixed_script','local_network_access','local_network','loopback_network',
  'web_app_installation','speaker_selection','bluetooth_scanning','display_media_system_audio','autoplay',
  'subresource_filter',   # "Intrusive ads"
  'webid_api'             # "Third-party sign-in"
)
# 3 = Ask (Chrome accepts only Ask/Block for these)
$ask = @('usb_guard','serial_guard','hid_guard','bluetooth_guard','file_system_write_guard','file_system_read_guard')

# ---- locate browser user-data dirs ----
$onWin = $IsWindows -or $env:OS -eq 'Windows_NT'
$home_ = if ($onWin) { $env:USERPROFILE } else { $env:HOME }
$dirs = if ($onWin) { @{
    chrome   = @{ path = "$env:LOCALAPPDATA\Google\Chrome\User Data";             proc = 'chrome' }
    edge     = @{ path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data";            proc = 'msedge' }
    brave    = @{ path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"; proc = 'brave' }
    vivaldi  = @{ path = "$env:LOCALAPPDATA\Vivaldi\User Data";                   proc = 'vivaldi' }
    chromium = @{ path = "$env:LOCALAPPDATA\Chromium\User Data";                  proc = 'chromium' }
  } } elseif ($IsMacOS) { @{
    chrome   = @{ path = "$home_/Library/Application Support/Google/Chrome";               proc = 'Google Chrome' }
    edge     = @{ path = "$home_/Library/Application Support/Microsoft Edge";              proc = 'Microsoft Edge' }
    brave    = @{ path = "$home_/Library/Application Support/BraveSoftware/Brave-Browser"; proc = 'Brave Browser' }
    vivaldi  = @{ path = "$home_/Library/Application Support/Vivaldi";                     proc = 'Vivaldi' }
    chromium = @{ path = "$home_/Library/Application Support/Chromium";                    proc = 'Chromium' }
  } } else { @{
    chrome   = @{ path = "$home_/.config/google-chrome";               proc = 'chrome' }
    edge     = @{ path = "$home_/.config/microsoft-edge";              proc = 'msedge' }
    brave    = @{ path = "$home_/.config/BraveSoftware/Brave-Browser"; proc = 'brave' }
    vivaldi  = @{ path = "$home_/.config/vivaldi";                     proc = 'vivaldi-bin' }
    chromium = @{ path = "$home_/.config/chromium";                    proc = 'chromium' }
  } }

$targets = foreach ($b in $Browsers) { $d = $dirs[$b.ToLower()]; if ($d -and (Test-Path (Join-Path $d.path 'Local State'))) { [pscustomobject]@{ name = $b; path = $d.path; proc = $d.proc } } }
if (-not $targets) { Write-Warning 'No installed Chromium browsers found.'; return }

# ---- make sure they are closed ----
$running = @($targets | Where-Object { Get-Process -Name $_.proc -ErrorAction SilentlyContinue })
if ($running -and -not $WhatIf) {
  if (-not $CloseBrowsers) { throw "Close these browsers first (or pass -CloseBrowsers): $($running.name -join ', ')" }
  foreach ($t in $running) { Get-Process -Name $t.proc -ErrorAction SilentlyContinue | ForEach-Object { $null = $_.CloseMainWindow() } }
  $n = 0; while (($running | Where-Object { Get-Process -Name $_.proc -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0 }) -and $n -lt 20) { Start-Sleep 1; $n++ }
  Start-Sleep 3
  foreach ($t in $running) { Get-Process -Name $t.proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
  Start-Sleep 2
}

# ---- write ----
$stamp = Get-Date -Format yyyyMMdd-HHmmss
$now = [string]([long]([DateTime]::UtcNow.ToFileTimeUtc() / 10))   # microseconds since 1601
$changed = 0
foreach ($t in $targets) {
  $profiles = (Get-Content (Join-Path $t.path 'Local State') -Raw | ConvertFrom-Json).profile.info_cache.PSObject.Properties.Name
  foreach ($p in $profiles) {
    $pf = Join-Path (Join-Path $t.path $p) 'Preferences'
    if (-not (Test-Path $pf)) { continue }
    if ($WhatIf) { "would update: $($t.name) / $p"; continue }
    Copy-Item $pf "$pf.bak-$stamp"
    $j = Get-Content $pf -Raw | ConvertFrom-Json -AsHashtable
    if (-not $j.profile) { $j.profile = @{} }
    if (-not $j.profile.content_settings) { $j.profile.content_settings = @{} }
    if (-not $j.profile.content_settings.exceptions) { $j.profile.content_settings.exceptions = @{} }
    $ex = $j.profile.content_settings.exceptions
    foreach ($type in ($allow + $ask)) {
      if ($Remove) {
        if ($ex[$type] -is [System.Collections.IDictionary]) { foreach ($pat in $patterns) { $ex[$type].Remove($pat) } }
        continue
      }
      if ($ex[$type] -isnot [System.Collections.IDictionary]) { $ex[$type] = @{} }
      $val = if ($ask -contains $type) { 3 } else { 1 }
      foreach ($pat in $patterns) { $ex[$type][$pat] = [ordered]@{ last_modified = $now; setting = $val } }
    }
    [IO.File]::WriteAllText($pf, ($j | ConvertTo-Json -Depth 100 -Compress), (New-Object Text.UTF8Encoding $false))
    "updated: $($t.name) / $p"
    $changed++
  }
}
if (-not $WhatIf) { "Done: $changed profile(s), $($hosts.Count) site(s): $($hosts -join ', '). Mode: $(if ($Remove) {'removed'} else {'allow'})." }
