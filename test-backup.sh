#!/usr/bin/env bash
# test-backup.sh — integration tests for ai-backup and ai-restore
# Run before every checkin:  bash ~/ai-backup-mac/test-backup.sh
# Exits 0 if all pass, 1 if any fail.

set -euo pipefail

REPO="$HOME/ai-backup-mac"
PASS=0
FAIL=0
BAK_PATTERN=""

# ── Helpers ───────────────────────────────────────────────────────────────────
pass()    { echo "  ✅ PASS  $1"; PASS=$((PASS + 1)); }
fail()    { echo "  ❌ FAIL  $1"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1 ──────────────────────────────────────────"; }

check() {
  local label="$1"; shift
  if "$@" &>/dev/null; then pass "$label"; else fail "$label"; fi
}

check_grep() {
  local label="$1"; local pattern="$2"; local file="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then pass "$label"; else fail "$label"; fi
}

check_no_grep() {
  local label="$1"; local pattern="$2"; local file="$3"
  if ! grep -q "$pattern" "$file" 2>/dev/null; then pass "$label"; else fail "$label"; fi
}

cleanup() {
  echo ""
  echo "── Cleanup ──────────────────────────────────────────────────────"
  python3 << 'EOF'
import shutil, os, glob
home = os.path.expanduser('~')
targets = [
    os.path.join(home, '.agents/skills/TEST-backup-skill'),
]
targets += glob.glob(os.path.join(home, '.agents/skills.bak-*'))
targets += glob.glob(os.path.join(home, '.claude.bak-*'))
targets += glob.glob(os.path.join(home, 'Library/Application Support/Claude/*.bak-*'))
for t in targets:
    if os.path.isdir(t):  shutil.rmtree(t);  print(f'  removed dir  {t}')
    elif os.path.isfile(t): os.remove(t);    print(f'  removed file {t}')
EOF
}

trap cleanup EXIT

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           ai-backup-mac integration test suite           ║"
echo "╚══════════════════════════════════════════════════════════╝"

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
section "Prerequisites"

check      "repo exists"              test -d "$REPO/.git"
check      "backup-paths.conf exists" test -f "$REPO/backup-paths.conf"
check      "ai-backup is executable"  test -x "/opt/homebrew/bin/ai-backup"
check      "ai-restore is executable" test -x "/opt/homebrew/bin/ai-restore"
check_grep "git remote is ai-backup-mac" "ai-backup-mac" <(cd "$REPO" && git remote -v)

# ── 2. Set up test fixtures ───────────────────────────────────────────────────
section "Setting up test fixtures"

SKILL_FILE="$HOME/.agents/skills/git-advanced-workflows/SKILL.md"
CLAUDE_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
CLAUDE_CODE_FILE="$HOME/.claude/plugins.json"
TEST_SKILL_DIR="$HOME/.agents/skills/TEST-backup-skill"

check "SKILL_FILE exists"     test -f "$SKILL_FILE"
check "CLAUDE_CFG exists"     test -f "$CLAUDE_CFG"
check "CLAUDE_CODE_FILE exists" test -f "$CLAUDE_CODE_FILE"

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

# ── 3. Test ai-backup ─────────────────────────────────────────────────────────
section "Test: ai-backup"

if bash /opt/homebrew/bin/ai-backup > /tmp/ai-backup-test.log 2>&1; then
  pass "ai-backup exits successfully"
else
  fail "ai-backup exits successfully (exit $?) — see /tmp/ai-backup-test.log"
fi

check      "test skill captured in repo"    test -f "$REPO/skills/TEST-backup-skill/SKILL.md"
check      "claude_desktop_config captured" test -f "$REPO/files/Claude/claude_desktop_config.json"
check      "plugins.json captured"          test -f "$REPO/.claude/plugins.json"
check_grep "backup logged"                  "BACKUP" "$REPO/ai-backup.log"

BACKUP_COMMIT=$(cd "$REPO" && git log -1 --pretty=format:"%h" --grep="^backup:" 2>/dev/null || true)
check "backup commit exists in git" test -n "$BACKUP_COMMIT"

# ── 4. Corrupt one file in each category ─────────────────────────────────────
section "Corrupting files (simulating breakage)"

python3 << EOF
import os
for path, content in [
    ('$SKILL_FILE',       'CORRUPTED: skill'),
    ('$CLAUDE_CFG',       '{"CORRUPTED": "claude_desktop_config"}'),
    ('$CLAUDE_CODE_FILE', '{"CORRUPTED": "plugins.json"}'),
    ('$TEST_SKILL_DIR/SKILL.md', 'CORRUPTED: test skill'),
]:
    open(path, 'w').write(content + '\n')
    print(f'  corrupted: {path}')
EOF

check_grep "skill is corrupted"              "CORRUPTED" "$SKILL_FILE"
check_grep "claude_desktop_config corrupted" "CORRUPTED" "$CLAUDE_CFG"
check_grep "plugins.json corrupted"          "CORRUPTED" "$CLAUDE_CODE_FILE"
check_grep "test skill corrupted"            "CORRUPTED" "$TEST_SKILL_DIR/SKILL.md"

# ── 5. Test ai-restore --last ─────────────────────────────────────────────────
section "Test: ai-restore --last"

if echo "y" | bash /opt/homebrew/bin/ai-restore --last > /tmp/ai-restore-test.log 2>&1; then
  pass "ai-restore exits successfully"
else
  fail "ai-restore exits successfully — see /tmp/ai-restore-test.log"
fi

BAK_PATTERN=$(grep -o '\.bak-[0-9-]*' /tmp/ai-restore-test.log | head -1 || true)
check "bak suffix detected in output" test -n "$BAK_PATTERN"

# ── 6. Verify files restored correctly ───────────────────────────────────────
section "Verifying restored content"

check_no_grep "skill restored"              "CORRUPTED" "$SKILL_FILE"
check_grep    "skill content correct"       "git-advanced-workflows" "$SKILL_FILE"
check_no_grep "claude_desktop_config restored" "CORRUPTED" "$CLAUDE_CFG"
check_no_grep "plugins.json restored"       "CORRUPTED" "$CLAUDE_CODE_FILE"
check_no_grep "test skill restored"         "CORRUPTED" "$TEST_SKILL_DIR/SKILL.md"

# ── 7. Verify bad files preserved ────────────────────────────────────────────
section "Verifying bad files preserved"

if [ -n "$BAK_PATTERN" ]; then
  BAK_SKILLS="$HOME/.agents/skills${BAK_PATTERN}"
  BAK_CLAUDE="$HOME/.claude${BAK_PATTERN}"
  check     "bad skills dir preserved" test -d "$BAK_SKILLS"
  check_grep "corrupted skill in bak"  "CORRUPTED" "${BAK_SKILLS}/git-advanced-workflows/SKILL.md"
  check     "bad .claude dir preserved" test -d "$BAK_CLAUDE"
  check_grep "corrupted plugins.json in bak" "CORRUPTED" "${BAK_CLAUDE}/plugins.json"
else
  fail "could not determine bak suffix — skipping bak file checks"
  fail "bad skills dir preserved"
  fail "corrupted skill in bak"
  fail "bad .claude dir preserved"
  fail "corrupted plugins.json in bak"
fi

# ── 8. Test ai-restore list mode ─────────────────────────────────────────────
section "Test: ai-restore (list mode)"

bash /opt/homebrew/bin/ai-restore > /tmp/ai-restore-list.log 2>&1 || true
check_grep "list shows header"     "Available backups"  /tmp/ai-restore-list.log
check_grep "list shows commits"    "backup:"            /tmp/ai-restore-list.log
check_grep "list shows usage hint" "ai-restore --last"  /tmp/ai-restore-list.log

# ── 9. Test no-op backup ──────────────────────────────────────────────────────
section "Test: ai-backup with no changes"

bash /opt/homebrew/bin/ai-backup > /tmp/ai-backup-noop.log 2>&1
check_grep "no-op backup detects no changes" "Nothing changed" /tmp/ai-backup-noop.log

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  printf "║  ✅  ALL %d TESTS PASSED%-28s║\n" "$TOTAL" ""
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  exit 0
else
  printf "║  ❌  %d PASSED, %d FAILED (of %d)%-22s║\n" "$PASS" "$FAIL" "$TOTAL" ""
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  echo "  Logs: /tmp/ai-backup-test.log  /tmp/ai-restore-test.log"
  echo ""
  exit 1
fi
