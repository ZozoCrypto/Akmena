#!/bin/bash
# Invariant campaign runner with immutable header
# Per Aegis 2026-10-03: every security result must trace to its candidate revision
#
# Usage: ./script/run-invariant-campaign.sh [log-file]
# Output: log file with immutable header + forge test results

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

LOG_FILE="${1:-test-logs/invariant_campaign_$(date +%Y%m%d_%H%M%S).log}"
CANDIDATE_REV=$(git rev-parse HEAD)
CANDIDATE_SHORT=$(git rev-parse --short HEAD)
WORKING_TREE=$(git status --porcelain | head -5)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── Immutable header ──
{
  echo "======================================================================"
  echo "AKMENA INVARIANT CAMPAIGN — IMMUTABLE HEADER"
  echo "======================================================================"
  echo "Candidate revision: $CANDIDATE_REV ($CANDIDATE_SHORT)"
  echo "Working tree: $([ -z "$WORKING_TREE" ] && echo "clean" || echo "DIRTY")"
  if [ -n "$WORKING_TREE" ]; then
    echo "Working tree changes:"
    echo "$WORKING_TREE"
  fi
  echo "Invariant suite: 17 suites (test/invariant/*)"
  echo "Started: $TIMESTAMP (UTC)"
  echo ""
  echo "Relevant security patches included:"
  # GAP-1: check if the zero-value native fix is in history
  if git log --oneline --grep="GAP-1" -1 | grep -q .; then
    echo "  - GAP-1 (zero-value native DoS fix): $(git log --oneline --grep="GAP-1" -1 | cut -d' ' -f1)"
  else
    echo "  - GAP-1: NOT FOUND in history"
  fi
  # GAP-3: check if the confused-deputy hardening is in history
  if git log --oneline --grep="GAP-3" -1 | grep -q .; then
    echo "  - GAP-3 (confused-deputy hardening): $(git log --oneline --grep="GAP-3" -1 | cut -d' ' -f1)"
  fi
  # GAP-3 isEnabled: check if the isEnabled patch is in history
  if git log --oneline --grep="isEnabled" -1 | grep -q .; then
    echo "  - GAP-3 isEnabled (disabled module rejection): $(git log --oneline --grep="isEnabled" -1 | cut -d' ' -f1)"
  else
    echo "  - GAP-3 isEnabled: NOT FOUND in history"
  fi
  echo ""
  echo "Command: forge test --match-path \"test/invariant/*\""
  echo "======================================================================"
  echo ""
} > "$LOG_FILE"

echo "Header written to $LOG_FILE"
echo "Candidate: $CANDIDATE_SHORT"
echo "Starting invariant campaign..."

# ── Run the campaign ──
export PATH="$HOME/.foundry/bin:$PATH"
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

forge test --match-path "test/invariant/*" >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

echo "EXIT:$EXIT_CODE" >> "$LOG_FILE"

# ── Footer ──
{
  echo ""
  echo "======================================================================"
  echo "CAMPAIGN COMPLETE"
  echo "Finished: $(date -u +"%Y-%m-%dT%H:%M:%SZ") (UTC)"
  echo "Exit code: $EXIT_CODE"
  echo "Candidate revision: $CANDIDATE_REV"
  echo "======================================================================"
} >> "$LOG_FILE"

echo "Campaign complete. Exit: $EXIT_CODE"
echo "Log: $LOG_FILE"
exit $EXIT_CODE
