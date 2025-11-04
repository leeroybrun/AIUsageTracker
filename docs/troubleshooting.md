# AIUsageTracker Troubleshooting Guide

## Common Issues

### Missing Cursor Usage Data
1. Open **Settings → Automation** and run *Import Cursor Session Cookie* to ensure credentials are fresh.
2. Confirm the Cursor desktop app is logged in; individual accounts must generate traffic after you import cookies.
3. Check `~/Library/Application Support/AIUsageTracker/usage-cache.json` to verify events are being cached. Delete the file to reset the incremental pipeline if it becomes corrupted.

### External Provider Totals Are Empty
1. Ensure OpenAI/Anthropic/Gemini toggles are enabled in **Settings → Providers**.
2. Re-enter credentials if the Keychain secrets were removed.
3. Look at `~/Library/Application Support/AIUsageTracker/advanced-config.json` to confirm provider overrides are not disabling ingestion.

### Proxy Ingestion Server Won't Start
1. Verify the configured port is free: run `lsof -i :<port>`.
2. Toggle the *Enable proxy ingestion server* switch off/on; the background listener will restart and log progress to `~/Library/Caches/AIUsageTracker/diagnostics.log`.
3. Post usage payloads manually with `curl` to `http://localhost:<port>/ingest` to verify reachability.

### WebSocket Bridge Not Broadcasting
1. Confirm the *Enable WebSocket bridge* toggle is turned on and matches your tooling's port.
2. Tail the diagnostics log to see connection attempts.
3. The bridge only streams after a refresh; trigger **Refresh now** from the menu.

### Notifications Not Appearing
1. macOS may block alerts on first launch. Open **System Settings → Notifications** and enable AIUsageTracker.
2. Ensure the *Notification threshold* is less than `1.0` so predictions emit warnings before exhaustion.
3. Manually increase usage to trigger a warning; alerts only fire for `warning` or `critical` severities.

## Diagnostics Bundle
1. Toggle **Enable diagnostics logging** in Settings.
2. Reproduce the issue to populate `diagnostics.log`.
3. Collect the following files for support:
   - `~/Library/Caches/AIUsageTracker/diagnostics.log`
   - `~/Library/Application Support/AIUsageTracker/advanced-config.json`
   - `~/Library/Application Support/AIUsageTracker/usage-cache.json`
4. Compress and share with the development team.

## Resetting the App
1. Click **Clear App Cache** in Settings.
2. Remove `advanced-config.json` if you need a fresh configuration.
3. Relaunch AIUsageTracker and re-authenticate providers.
