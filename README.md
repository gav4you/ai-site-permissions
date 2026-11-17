# ai-site-permissions

A Claude Code skill that sets **every site setting to Allow** for Claude, ChatGPT, Gemini, or any site you name.
It covers **every profile** of Chrome, Edge, Brave, Vivaldi and Chromium on Windows, macOS and Linux.

It writes the per-site exceptions straight into each profile, so the site's settings page reads *Allow* everywhere,
as if you'd clicked through each one by hand. That includes location, camera, mic, notifications, clipboard,
pop-ups, downloads, intrusive ads, third-party sign-in and ~40 more. USB, serial, HID, Bluetooth and file editing
are set to **Ask**, since that's the most Chrome allows for those.

## Install (Claude Code)

```
/plugin marketplace add gav4you/ai-site-permissions
/plugin install ai-site-permissions@ai-site-permissions
```

Then just ask: *"allow all site settings for claude.ai and chatgpt in all my Chrome profiles"*.

## Run the script directly

Requires PowerShell 7+ (`pwsh`). Close your browsers first, or pass `-CloseBrowsers`.

```powershell
# preview
pwsh skills/allow-site-permissions/scripts/allow-site-permissions.ps1 -Sites ai -Subdomains -WhatIf
# apply (presets: claude, chatgpt, gemini, ai; or any hostnames)
pwsh skills/allow-site-permissions/scripts/allow-site-permissions.ps1 -Sites claude.ai,chatgpt.com -Subdomains -CloseBrowsers
# undo
pwsh skills/allow-site-permissions/scripts/allow-site-permissions.ps1 -Sites ai -Subdomains -Remove
```

Each changed `Preferences` file is backed up as `Preferences.bak-<timestamp>`.

## Caveats
- Browsers must be closed while it runs; otherwise they overwrite the change on exit.
- Firefox isn't covered (it uses `permissions.sqlite`); use its `Permissions` enterprise policy instead.
- Granting everything to a site is your call; only do it for sites you trust.

MIT licensed.
