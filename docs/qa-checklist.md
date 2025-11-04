# AIUsageTracker QA Checklist

1. **Boot & Credentials**
   - Launch app, import Cursor cookie via Settings automation, verify usage populates.
   - Add OpenAI/Anthropic/Gemini keys and confirm provider totals appear.
2. **Live Monitoring**
   - Toggle live monitoring mode and observe sparkline updates during refresh.
   - Trigger incremental refresh by creating new events via proxy ingestion curl payload.
3. **Forecast Alerts**
   - Adjust notification threshold to `0.1`, run refresh, verify notification delivered and dock badge shown.
4. **Developer Integrations**
   - Enable WebSocket bridge, connect via `websocat ws://localhost:8790`, ensure snapshots stream on refresh.
   - Check status export JSON updates at configured path.
5. **Proxy & Diagnostics**
   - Start proxy ingestion server, post sample payload, confirm diagnostics log records ingestion.
   - Inspect `advanced-config.schema.json` and validate custom config merges into settings.
6. **Localization**
   - Change macOS language to Spanish, restart, ensure localized menu strings render.
7. **Cleanup**
   - Clear app cache, confirm Keychain entries removed and UI prompts for login again.
