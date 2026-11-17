---
name: allow-site-permissions
description: Use when the user wants every site setting/permission (camera, mic, location, notifications, clipboard, pop-ups, intrusive ads, downloads, etc.) set to Allow for specific websites — e.g. claude.ai, chatgpt.com, gemini.google.com — in Chrome, Edge, Brave, Vivaldi or Chromium, across every browser profile. Also for undoing it.
---

# Allow all site permissions for chosen sites

Sets every Chromium site setting to **Allow** for the sites the user names, in **every profile** of every
installed Chromium browser, by writing the per-site exceptions straight into each profile's `Preferences`.
They then appear as "Allow" in *Settings → Privacy and security → Site settings → [site]*, exactly as if
set by hand.

## Why not enterprise policy?
Policies (`*AllowedForUrls`) only cover some permissions (none for location, USB, intrusive ads, etc.),
mark the browser "Managed by your organization", and users still see "Ask" in the site-settings page.
Editing each profile's own settings is what actually matches "set it to Allow for each profile".

## Steps

1. **Confirm the sites.** Presets: `claude` (claude.ai, clau.de), `chatgpt` (chatgpt.com, chat.openai.com),
   `gemini` (gemini.google.com), `ai` (all of them). Any other hostname works too. Prefer exact hosts over
   whole parent domains (e.g. `gemini.google.com`, not `google.com`).
2. **Preview:** `pwsh <skill-dir>/scripts/allow-site-permissions.ps1 -Sites <sites> -Subdomains -WhatIf`
   lists every browser/profile that will change.
3. **Ask the user before closing their browsers.** The browsers must be fully closed, or they overwrite
   the change on exit. Closing interrupts open tabs, logins and any automation driving the browser.
4. **Apply:** add `-CloseBrowsers` (only after the user says yes), or have the user close them first:
   `pwsh <skill-dir>/scripts/allow-site-permissions.ps1 -Sites ai -Subdomains -CloseBrowsers`
5. **Reopen and verify.** Relaunch with `--restore-last-session` so tabs come back. After ~15 s, re-read a
   profile's `Preferences` and check e.g. `profile.content_settings.exceptions.geolocation["https://<host>:443,*"].setting == 1`.
   This proves the browser kept the values.

Undo: same command with `-Remove`. Each changed file is backed up as `Preferences.bak-<timestamp>`.

## What gets set
- **Allow (1):** location, notifications, camera, mic, camera pan-tilt-zoom, sensors, MIDI, clipboard,
  payment handlers, pop-ups & redirects, automatic downloads, JavaScript (+JIT/optimizer), images, sound,
  cookies, background sync, idle detection, window management, fonts, protected content, AR/VR,
  hand tracking, auto picture-in-picture, auto fullscreen, keyboard/pointer lock, scrolling & zooming
  shared tabs, storage access, insecure content, local network, app install, speaker selection,
  autoplay, **intrusive ads** (`subresource_filter`), **third-party sign-in** (`webid_api`).
- **Ask (3):** USB, serial, HID, Bluetooth, file reading/editing. Chrome offers only Ask or Block for
  these, so Ask is the most permissive value.

If the user says a setting is still "Ask", find its content-settings key (it appears under
`profile.content_settings.exceptions` once set by hand in any profile), add it to `$allow` in the script, and rerun.

## Notes
- Requires PowerShell 7+ (`pwsh`), on Windows, macOS or Linux.
- Firefox stores permissions in `permissions.sqlite` and is not covered. Use the Firefox `Permissions`
  enterprise policy (Camera/Microphone/Location/Notifications/Autoplay `Allow` lists) instead.
- New profiles created later need a rerun.
