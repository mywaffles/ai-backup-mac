#!/usr/bin/env bash
# test-backup.sh — integration tests for ai-backup and ai-restore
# Run before every checkin. Exits 0 if all pass, 1 if any fail.

set -euo pipefail

REPO="$HOME/ai-backup-mac"
PASS=0
FAIL=0
BAK_PATTERN=""

# ── Helpers ──────────────────────────────────────────────────────────────────
pass() { echo "  ✅ PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL  $1"; FAIL=$((FAIL + 1)); }

check() {
  local label="$1"
  local condition="$2"
  if eval "$condition"; then pass "$label"; else fail "$label"; fi
}

section() { echo ""; echo "── $1 ──────────────────────────────────────────"; }

cleanup() {
  echo ""
  echo "── Cleanup ─────────────────────────────────────────────────────"
  # Remove test skill
  python3 -c "
import shutil, os, glob
td = os.path.expanduser('~/.agents/skills/TEST-backup-skill')
if os.path.exists(td): shutil.rmtree(td); print('  removed test skill')
for p in glob.glob(os.path.expanduser('~/.agents/skills.bak-*')): shutil.rmtree(p); print('  removed', p)
for p in glob.glob(os.path.expanduser('~/.claude.bak-*')): shutil.rmtree(p); print('  removed', p)
for p in glob.glob(os.path.expanduser('~/Library/Application Support/Claude/*.bak-*')): os.remove(p); print('  removed', p)
"
}

trap cleanup EXIT

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              ai-backup / ai-restore test suite           ║"
echo "╚══════════════════════════════════════════════════════════╝"

# ── 1. Prerequisites ─────────────────────────────────────────────────────────
section "Prerequisites"

check "repo exists at ~/ai-backup-mac"      "[ -d '$REPO/.git' ]"
check "backup-paths.conf exists"            "[ -f '$REPO/backup-paths.conf' ]"
check "ai-backup is executable"             "[ -x '/opt/homebrew/bin/ai-backup' ]"
check "ai-restore is executable"            "[ -x '/opt/homebrew/bin/ai-restore' ]"
check "git remote is ai-backup-mac"         "cd '$REPO' && git remote -v | grep -q 'ai-backup-mac'"

# ── 2. Set up test fixtures ──────────────────────────────────────────────────
section "Setting up test fixtures"

# Record originals before any corruption
SKILL_ORIG="$HOME/.agents/skills/git-advanced-workflows/SKILL.md"
CLAUDE_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
CLAUDE_CODE_FILE="$HOME/.claude/plugins.json"

SKILL_ORIG_CONTENT=$(cat "$SKILL_ORIG")
CFG_ORIG_CONTENT=$(cat "$CLAUDE_CFG")
CODE_ORIG_CONTENT=$(cat "$CLAUDE_CODE_FILE")

# Create a fresh test skill
TEST_SKILL_DIR="$HOME/.agents/skills/TEST-backup-skill"
mkdir -p "$TEST_SKILL_DIR"
cat > "$TEST_SKILL_DIR/SKILL.md" << 'EOF'
---
name: TEST-backup-skill
description: Created by test-backup.sh — safe to delete.
---
# Test Skill Original Content
This file is created and deleted by the test suite.
EOF
echo "  created test skill: TEST-backup-skill"

# ── 3. Test ai-backup ────────────────────────────────────────────────────────
section "Test: ai-backup"

bash /opt/homebrew/bin/ai-backup > /tmp/ai-backup-test.log 2>&1
check "ai-backup exits successfully"        "[ $? -eq 0 ]"
check "test skill captured in repo"         "[ -f '$REPO/skills/TEST-backup-skill/SKILL.md' ]"
check "claude_desktop_config captured"      "[ -f '$REPO/files/Claude/claude_desktop_config.json' ]"
check "plugins.json captured"              "[ -f '$REPO/.claude/plugins.json' ]"
check "backup logged to ai-backup.log"      "grep -q 'BACKUP' '$REPO/ai-backup.log'"

BACKUP_COMMIT=$(cd "$REPO" && git log -1 --pretty=format:"%h" --grep="^backup:")
check "backup commit created in git"        "[ -n '$BACKUP_COMMIT' ]"

# ── 4. Corrupt one file in each category ────────────────────────────────────
section "Corrupting files (simulating breakage)"

python3 << EOF
import os
files = [
    ('$SKILL_ORIG',     'CORRUPTED: skill'),
    ('$CLAUDE_CFG',     '{"CORRUPTED": "claude_desktop_config"}'),
    ('$CLAUDE_CODE_FILE', '{"CORRUPTED": "plugins.json"}'),
    ('$TEST_SKILL_DIR/SKILL.md', 'CORRUPTED: test skill'),
]
for path, content in files:
    open(path, 'w').write(content + '\n')
    print(f'  corrupted: {path}')
EOF

check "skill is corrupted"          "grep -q CORRUPTED '$SKILL_ORIG'"
check "claude_desktop_config is corrupted" "grep -q CORRUPTED '$CLAUDE_CFG'"
check "plugins.json is corrupted"   "grep -q CORRUPTED '$CLAUDE_CODE_FILE'"
check "test skill is corrupted"     "grep -q CORRUPTED '$TEST_SKILL_DIR/SKILL.md'"

# ── 5. Test ai-restore --last ────────────────────────────────────────────────
section "Test: ai-restore --last"

echo "y" | bash /opt/homebrew/bin/ai-restore --last > /tmp/ai-restore-test.log 2>&1
RESTORE_EXIT=$?
check "ai-restore exits successfully"       "[ $RESTORE_EXIT -eq 0 ]"

# Grab the bak suffix from the log output
BAK_PATTERN=$(grep "Renaming existing files with suffix:" /tmp/ai-restore-test.log | grep -o '\.bak-[0-9-]*' || echo "")
check "bak suffix detected in output"       "[ -n '$BAK_PATTERN' ]"

# ── 6. Verify files restored correctly ──────────────────────────────────────
section "Verifying restored content"

check "skill restored (no CORRUPTED)"       "! grep -q CORRUPTED '$SKILL_ORIG'"
check "skill content correct"               "grep -q 'git-advanced-workflows' '$SKILL_ORIG'"
check "claude_desktop_config restored"      "! grep -q CORRUPTED '$CLAUDE_CFG'"
check "plugins.json restored"              "! grep -q CORRUPTED '$CLAUDE_CODE_FILE'"
check "test skill restored"                 "[ -f '$TEST_SKILL_DIR/SKILL.md' ] && ! grep -q CORRUPTED '$TEST_SKILL_DIR/SKILL.md'"

# ── 7. Verify bad files preserved ───────────────────────────────────────────
section "Verifying bad files were preserved"

if [ -n "$BAK_PATTERN" ]; then
  BAK_SKILLS="$HOME/.agents/skills${BAK_PATTERN}"
  BAK_CLAUDE="$HOME/.claude${BAK_PATTERN}"
  check "bad skills dir preserved"          "[ -d '$BAK_SKILLS' ]"
  check "bad skill content in bak"          "grep -q CORRUPTED '${BAK_SKILLS}/git-advanced-workflows/SKILL.md'"
  check "bad .claude dir preserved"         "[ -d '$BAK_CLAUDE' ]"
  check "bad plugins.json in bak"           "grep -q CORRUPTED '${BAK_CLAUDE}/plugins.json'"
else
  fail "could not determine bak suffix — skipping bak file checks"
fi

# ── 8. Test ai-restore list ──────────────────────────────────────────────────
section "Test: ai-restore (list mode)"

bash /opt/homebrew/bin/ai-restore > /tmp/ai-restore-list.log 2>&1 || true
check "list shows available backups"        "grep -q 'Available backups' /tmp/ai-restore-list.log"
check "list shows backup commits"           "grep -q 'backup:' /tmp/ai-restore-list.log"
check "list shows usage instructions"       "grep -q 'ai-restore --last' /tmp/ai-restore-list.log"

# ── 9. Test no-op backup ─────────────────────────────────────────────────────
section "Test: ai-backup with no changes"

bash /opt/homebrew/bin/ai-backup > /tmp/ai-backup-noop.log 2>&1
check "no-op backup detects no changes"     "grep -q 'Nothing changed' /tmp/ai-backup-noop.log"

# ── Results ──────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
  printf "║  ✅  ALL %d TESTS PASSED                                  ║\n" "$TOTAL"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  exit 0
else
  printf "║  ❌  %d PASSED, %d FAILED (of %d)                          ║\n" "$PASS" "$FAIL" "$TOTAL"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  echo "Logs:"
  echo "  /tmp/ai-backup-test.log"
  echo "  /tmp/ai-restore-test.log"
  echo ""
  exit 1
fi
