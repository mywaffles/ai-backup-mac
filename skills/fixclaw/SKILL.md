---
name: fixclaw
description: >
  Diagnose and repair OpenClaw problems automatically. Use this skill whenever
  something is wrong with OpenClaw, the gateway, channels (Telegram, BlueBubbles,
  Discord), agents, cron jobs, sessions, or skills. Triggers on: "fix openclaw",
  "fixclaw", "claw is broken", "gateway won't start", "Telegram not working",
  "BlueBubbles down", "agent not responding", "openclaw error", "openclaw health
  shows errors", "cron not running", "messages not sending", "check openclaw",
  "repair openclaw", or any complaint about OpenClaw misbehaving. Also use when
  the user says "/fixclaw" with optional context about what's wrong. If necessary,
  restores the last backup using the ai-backup-mac skill. All commands run on the
  user's Mac Mini via shell:run_command.
---

# FixClaw — OpenClaw Auto-Repair

Diagnoses and fixes OpenClaw problems on Matt's Mac Mini M4.

## Philosophy

1. **Gather before acting** — run diagnostics first, understand the problem
2. **Fix non-destructively** — prefer config corrections over restarts, restarts over reinstalls
3. **Backup before destructive changes** — run `ai-backup` before modifying config files
4. **Verify after fixing** — confirm the dashboard loads, the agent responds, and channels work
5. **Learn from failures** — after fully resolved, evaluate whether this skill should be improved
6. **Report what you did** — always summarize findings and actions taken

---

## Diagnostic Sequence

Run these in order. Stop early if the problem is obvious and fixable.

### Phase 1: Quick Health Check

```bash
openclaw health 2>&1
```

This gives channel status (Telegram, BlueBubbles), agent list, heartbeat info,
and recent sessions. Look for:
- Channel failures (e.g., `Telegram: failed (404)`)
- Missing agents
- Stale sessions

### Phase 2: Doctor (Detailed Diagnostics)

```bash
openclaw doctor --non-interactive 2>&1
```

This checks:
- State integrity (orphan transcripts, corrupted session store)
- Duplicate gateway services (old plist files)
- Gateway token mismatches (service token vs config token)
- Security warnings (LAN binding, weak auth)
- Skills eligibility
- Plugin status

### Phase 3: Logs (If Problem Unclear)

```bash
openclaw logs --limit 100 --plain --no-color 2>&1
```

Look for:
- Repeated errors or stack traces
- API key failures (401/403)
- Connection timeouts
- Channel-specific errors

Also check the system log location:
```bash
ls -lt /tmp/openclaw/ 2>/dev/null | head -5
tail -50 /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log 2>/dev/null
```

### Phase 4: System-Level Checks

```bash
# Is the gateway process running?
pgrep -fl openclaw 2>&1

# Is the gateway port open?
lsof -i :18789 2>&1

# LaunchAgent status (gateway + node)
launchctl list | grep openclaw 2>&1
launchctl list | grep ai.openclaw 2>&1

# Node host status
openclaw node status 2>&1
```

### Phase 5: Security Audit (Optional)

```bash
openclaw security audit 2>&1
```

Checks for plaintext secrets in config, weak credentials, and other security issues.
Run if Phase 1-4 don't reveal the problem, or after any config repair.

---

## Known Problems & Fixes

These are problems that have actually occurred on this system, ordered by likelihood.

### LaunchAgent / Node Host Not Installed
**Symptoms:** Gateway won't start, "Service unit not found", "Service not installed" in logs.
**Seen when:** Fresh install, after updates, or after macOS upgrade.
```bash
openclaw gateway install 2>&1
openclaw gateway start 2>&1
# Also check the node host — if missing, ALL requests silently time out
openclaw node status 2>&1
openclaw node install 2>&1
openclaw node start 2>&1
```
**IMPORTANT:** If only the gateway is installed but the node host is missing, the gateway
will appear healthy but every request will return "NO" or time out silently. Always check both.

### Device Platform Mismatch (After macOS Upgrade)
**Symptoms:** Gateway rejects connections with `code=1008 reason=pairing required`. Agent appears
to work in logs but all requests fail.
**Cause:** `~/.openclaw/devices/paired.json` stores the macOS version at pairing time. After
upgrading macOS (e.g., Sequoia 15.5 -> Tahoe 26), the stored platform string no longer matches.
```bash
cat ~/.openclaw/devices/paired.json 2>&1 | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d, indent=2))"
sw_vers 2>&1
```
Fix by updating the platform string in paired.json, then reinstalling the gateway:
```bash
python3 -c "
import json
p = '/Users/mattabar/.openclaw/devices/paired.json'
d = json.load(open(p))
# Update the platform field to match sw_vers output
json.dump(d, open(p, 'w'), indent=2)
"
openclaw gateway install --force 2>&1
```

### Agent Corrupted Config (Gay Deceiver Self-Editing)
**Symptoms:** Gateway fails to start, config parse errors, or unexpected behavior.
**Cause:** The agent sometimes writes directly to `~/.openclaw/openclaw.json`
instead of using `openclaw config set`, introducing invalid keys or breaking the JSON schema.
```bash
python3 -c "import json; json.load(open('/Users/mattabar/.openclaw/openclaw.json')); print('Config is valid JSON')" 2>&1
```
**NEVER edit openclaw.json directly to fix it.** Use `openclaw config set <path> <value>` or,
for structural repairs, use the Python read-write-to-tmp pattern:
```bash
python3 -c "
import json, shutil
src = '/Users/mattabar/.openclaw/openclaw.json'
shutil.copy(src, src + '.bak')
c = json.load(open(src))
# Apply targeted fix here
json.dump(c, open('/tmp/openclaw-fixed.json', 'w'), indent=2)
" 2>&1 && mv /tmp/openclaw-fixed.json /Users/mattabar/.openclaw/openclaw.json && chmod 600 /Users/mattabar/.openclaw/openclaw.json
```

### Telegram: failed (404)
**Cause:** Bot token invalid, bot deleted, webhook stale, or empty group allow list.
```bash
openclaw config get channels.telegram 2>&1
TOKEN=$(openclaw config get channels.telegram.botToken 2>&1 | tr -d '"')
curl -s "https://api.telegram.org/bot${TOKEN}/getMe" 2>&1
```
- If `getMe` returns `{"ok":false}` -> token is dead, user needs to regenerate via @BotFather
- If `getMe` returns `{"ok":true}` -> restart gateway: `openclaw gateway restart`

**Also check:** Empty `groupAllowFrom` silently drops all group messages:
```bash
openclaw config get channels.telegram.groupAllowFrom 2>&1
# If empty: openclaw config set channels.telegram.groupAllowFrom '[6823814370]'
```

### BlueBubbles: failed
**Cause:** BlueBubbles server not running, or password/URL changed.
```bash
pgrep -fl BlueBubbles 2>&1
openclaw config get channels.bluebubbles 2>&1
BB_URL=$(openclaw config get channels.bluebubbles.serverUrl 2>&1 | tr -d '"')
BB_PASS=$(openclaw config get channels.bluebubbles.password 2>&1 | tr -d '"')
curl -s "${BB_URL}/api/v1/server/info?password=${BB_PASS}" 2>&1 | head -c 200
```
- If not running -> `open -a BlueBubbles`
- If password mismatch -> read from config.db:
  ```bash
  sqlite3 ~/Library/Application\ Support/bluebubbles-server/config.db \
    "SELECT value FROM config WHERE key='password';" 2>&1
  ```
  Then: `openclaw config set channels.bluebubbles.password "<new_password>"`

**NOTE:** BlueBubbles has a known crash on macOS Tahoe 26.3 (code signature validation issue).

### Gateway Token Mismatch
**Cause:** Config updated but LaunchAgent still has the old token.
```bash
openclaw config get gateway.auth.token 2>&1
grep OPENCLAW_GATEWAY_TOKEN ~/Library/LaunchAgents/ai.openclaw.node.plist 2>&1
```
Fix: `openclaw doctor --fix --non-interactive`

### Gateway Not Running
```bash
lsof -i :18789 2>&1
openclaw gateway start 2>&1
# If port conflict:
openclaw gateway --force 2>&1
# If LaunchAgent stale:
launchctl bootout gui/$(id -u)/ai.openclaw.node 2>&1
openclaw node install 2>&1
openclaw node start 2>&1
```

### API Key Errors (OpenRouter 401/403)
**Cause:** Key disabled — can be re-enabled without regenerating.
```bash
openclaw models status 2>&1
OPENROUTER_KEY=$(openclaw config get models.providers.openrouter.apiKey 2>&1 | tr -d '"')
curl -s -H "Authorization: Bearer ${OPENROUTER_KEY}" \
  https://openrouter.ai/api/v1/auth/key 2>&1 | head -c 200
```
- "User not found" = key is disabled (not invalid). Re-enable at https://openrouter.ai/settings/keys
- After re-enabling: `openclaw gateway restart`

### TTS Auto-Playing Unexpectedly
**Cause:** `tts.auto` set to `"always"`.
```bash
openclaw config get tts 2>&1
```
Fix: `openclaw config set tts.auto "never"`

### ElevenLabs Talk Mode 401 Errors
**Cause:** Usually quota/billing, not invalid key. Key may appear active in dashboard but credits exhausted.
```bash
EL_KEY=$(openclaw config get tts.elevenlabs.apiKey 2>&1 | tr -d '"')
curl -s -H "xi-api-key: ${EL_KEY}" https://api.elevenlabs.io/v1/user 2>&1 | head -c 200
```
Check `character_count` vs `character_limit`. If near limit, inform user to check billing.

### Orphan Transcripts / Stale Sessions
```bash
openclaw doctor --fix --non-interactive 2>&1
```

### Old Gateway Plist Lingering
```bash
launchctl bootout gui/$(id -u)/ai.openclaw.gateway 2>/dev/null
rm -f ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

### Cron Jobs Not Firing
```bash
openclaw cron status 2>&1
openclaw cron list 2>&1
openclaw cron run <job-id> 2>&1
```

### Skills Not Loading
```bash
openclaw skills check 2>&1
```

---

## Escalation: Backup & Restore

### Before any destructive fix
```bash
ai-backup
```

### Restore last known good state
```bash
ai-restore --last
```

### Nuclear option (full config reset)
```bash
ai-backup  # always backup first
openclaw reset
openclaw configure  # re-run setup wizard
```

---

## Verification (REQUIRED — Do Not Skip)

After all fixes are applied, run these verification steps before reporting success.
ALL THREE must pass before declaring OpenClaw fixed.

### Step 1: Health Check Clean
```bash
openclaw health 2>&1
```
Confirm: no channel failures, agent listed, heartbeat recent.

### Step 2: Dashboard Responds
Use playwright-cli to verify the dashboard loads and the agent responds:
```bash
playwright-cli open "http://127.0.0.1:18789" --headed 2>&1
playwright-cli snapshot 2>&1
```
Look for error messages. Dashboard should show the agent and conversation UI.
Then send a test message:
```bash
# Find the message input and send a test
playwright-cli fill <input-ref> "Hello, how's it going?" 2>&1
playwright-cli press Enter 2>&1
sleep 15
playwright-cli snapshot 2>&1
```
Confirm the agent responded reasonably (not an error, not "NO", not a timeout).

### Step 3: Telegram Verification
```bash
TOKEN=$(openclaw config get channels.telegram.botToken 2>&1 | tr -d '"')
curl -s "https://api.telegram.org/bot${TOKEN}/getMe" 2>&1
curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates?limit=1&timeout=0" 2>&1 | head -c 500
# Send verification message
CHAT_ID=6823814370
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=🦞 FixClaw verification: OpenClaw is back online." 2>&1
```

---

## Post-Fix Self-Evaluation

After the fix is fully verified AND any user follow-up is resolved:

1. Was the problem already documented above? If not, add it.
2. Did any diagnostic step waste time? Add a hint to skip it for this class of problem.
3. Did verification catch something the fix missed? Update the fix procedure.
4. Is there a new shortcut? Promote recurring problems earlier in the diagnostic sequence.

If improvements are needed, rewrite this skill and port it using the skill-porter workflow.

---

## Response Format

```
🦞 FixClaw Report
─────────────────
Problems found:
- [what was wrong]

Actions taken:
- [what was fixed]

Verification:
- Health check: ✅/❌
- Dashboard test: ✅/❌
- Telegram test: ✅/❌

Still needs attention:
- [anything requiring user action]
```

If everything is clean: `🦞 OpenClaw is healthy. No issues found.`
