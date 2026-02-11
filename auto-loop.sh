#!/bin/bash
# ============================================================
# Auto Company — 24/7 Autonomous Loop
# ============================================================
# Keeps Claude Code running continuously to drive the AI team.
# Uses fresh sessions with consensus.md as the relay baton.
#
# Usage:
#   ./auto-loop.sh              # Run in foreground
#   ./auto-loop.sh --daemon     # Run via launchd (no tty)
#
# Stop:
#   ./stop-loop.sh              # Graceful stop
#   kill $(cat .auto-loop.pid)  # Force stop
#
# Config (env vars):
#   MODEL=sonnet                # Claude model (default: sonnet)
#   MAX_BUDGET_PER_CYCLE=5      # USD per cycle (default: 5)
#   LOOP_INTERVAL=30            # Seconds between cycles (default: 30)
#   MAX_CONSECUTIVE_ERRORS=5    # Circuit breaker threshold
#   COOLDOWN_SECONDS=300        # Cooldown after circuit break
#   LIMIT_WAIT_SECONDS=3600     # Wait on usage limit
#   MAX_LOGS=200                # Max cycle logs to keep
# ============================================================

set -euo pipefail

# === Resolve project root (always relative to this script) ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

LOG_DIR="$PROJECT_DIR/logs"
CONSENSUS_FILE="$PROJECT_DIR/memories/consensus.md"
PROMPT_FILE="$PROJECT_DIR/PROMPT.md"
PID_FILE="$PROJECT_DIR/.auto-loop.pid"
STATE_FILE="$PROJECT_DIR/.auto-loop-state"

# Loop settings (all overridable via env vars)
MODEL="${MODEL:-opus}"
MAX_BUDGET_PER_CYCLE="${MAX_BUDGET_PER_CYCLE:-5}"
LOOP_INTERVAL="${LOOP_INTERVAL:-30}"
MAX_CONSECUTIVE_ERRORS="${MAX_CONSECUTIVE_ERRORS:-5}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-300}"
LIMIT_WAIT_SECONDS="${LIMIT_WAIT_SECONDS:-3600}"
MAX_LOGS="${MAX_LOGS:-200}"

# Ensure Agent Teams is available
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# === Functions ===

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[$timestamp] $1"
    echo "$msg" >> "$LOG_DIR/auto-loop.log"
    if [ -t 1 ]; then
        echo "$msg"
    fi
}

log_cycle() {
    local cycle_num=$1
    local status=$2
    local msg=$3
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] Cycle #$cycle_num [$status] $msg" >> "$LOG_DIR/auto-loop.log"
    if [ -t 1 ]; then
        echo "[$timestamp] Cycle #$cycle_num [$status] $msg"
    fi
}

check_usage_limit() {
    local output="$1"
    if echo "$output" | grep -qi "usage limit\|rate limit\|too many requests\|resource_exhausted\|overloaded"; then
        return 0
    fi
    return 1
}

check_stop_requested() {
    if [ -f "$PROJECT_DIR/.auto-loop-stop" ]; then
        rm -f "$PROJECT_DIR/.auto-loop-stop"
        return 0
    fi
    return 1
}

save_state() {
    cat > "$STATE_FILE" << EOF
LOOP_COUNT=$loop_count
ERROR_COUNT=$error_count
LAST_RUN=$(date '+%Y-%m-%d %H:%M:%S')
STATUS=$1
MODEL=$MODEL
MAX_BUDGET_PER_CYCLE=$MAX_BUDGET_PER_CYCLE
EOF
}

cleanup() {
    log "=== Auto Loop Shutting Down (PID $$) ==="
    rm -f "$PID_FILE"
    save_state "stopped"
    exit 0
}

rotate_logs() {
    # Keep only the latest N cycle logs
    local count
    count=$(find "$LOG_DIR" -name "cycle-*.log" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt "$MAX_LOGS" ]; then
        local to_delete=$((count - MAX_LOGS))
        find "$LOG_DIR" -name "cycle-*.log" -type f | sort | head -n "$to_delete" | xargs rm -f 2>/dev/null || true
        log "Log rotation: removed $to_delete old cycle logs"
    fi

    # Rotate main log if over 10MB
    local log_size
    log_size=$(stat -f%z "$LOG_DIR/auto-loop.log" 2>/dev/null || echo 0)
    if [ "$log_size" -gt 10485760 ]; then
        mv "$LOG_DIR/auto-loop.log" "$LOG_DIR/auto-loop.log.old"
        log "Main log rotated (was ${log_size} bytes)"
    fi
}

backup_consensus() {
    if [ -f "$CONSENSUS_FILE" ]; then
        cp "$CONSENSUS_FILE" "$CONSENSUS_FILE.bak"
    fi
}

restore_consensus() {
    if [ -f "$CONSENSUS_FILE.bak" ]; then
        cp "$CONSENSUS_FILE.bak" "$CONSENSUS_FILE"
        log "Consensus restored from backup after failed cycle"
    fi
}

# === Setup ===

mkdir -p "$LOG_DIR" "$PROJECT_DIR/memories"

# Clean up stale stop file from previous run
rm -f "$PROJECT_DIR/.auto-loop-stop"

# Check for existing instance
if [ -f "$PID_FILE" ]; then
    existing_pid=$(cat "$PID_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
        echo "Auto loop already running (PID $existing_pid). Stop it first with ./stop-loop.sh"
        exit 1
    fi
fi

# Check dependencies
if ! command -v claude &>/dev/null; then
    echo "Error: 'claude' CLI not found in PATH. Install Claude Code first."
    exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: PROMPT.md not found at $PROMPT_FILE"
    exit 1
fi

# Write PID file
echo $$ > "$PID_FILE"

# Trap signals for graceful shutdown
trap cleanup SIGTERM SIGINT SIGHUP

# Initialize counters
loop_count=0
error_count=0

log "=== Auto Company Loop Started (PID $$) ==="
log "Project: $PROJECT_DIR"
log "Model: $MODEL | Budget: \$${MAX_BUDGET_PER_CYCLE}/cycle | Interval: ${LOOP_INTERVAL}s | Breaker: ${MAX_CONSECUTIVE_ERRORS} errors"

# === Main Loop ===

while true; do
    # Check for stop request
    if check_stop_requested; then
        log "Stop requested. Shutting down gracefully."
        cleanup
    fi

    loop_count=$((loop_count + 1))
    cycle_log="$LOG_DIR/cycle-$(printf '%04d' $loop_count)-$(date '+%Y%m%d-%H%M%S').log"

    log_cycle $loop_count "START" "Beginning work cycle"
    save_state "running"

    # Log rotation
    rotate_logs

    # Backup consensus before cycle
    backup_consensus

    # Build prompt with consensus pre-injected
    PROMPT=$(cat "$PROMPT_FILE")
    CONSENSUS=$(cat "$CONSENSUS_FILE" 2>/dev/null || echo "No consensus file found. This is the very first cycle.")
    FULL_PROMPT="$PROMPT

---

## Current Consensus (pre-loaded, do NOT re-read this file)

$CONSENSUS

---

This is Cycle #$loop_count. Act decisively."

    # Run Claude Code in headless mode
    set +e
    OUTPUT=$(cd "$PROJECT_DIR" && claude -p "$FULL_PROMPT" \
        --model "$MODEL" \
        --max-budget-usd "$MAX_BUDGET_PER_CYCLE" \
        --dangerously-skip-permissions \
        --output-format json \
        2>&1)
    EXIT_CODE=$?
    set -e

    # Save full output to cycle log
    echo "$OUTPUT" > "$cycle_log"

    # Extract result and cost
    RESULT_TEXT=""
    CYCLE_COST=""
    if command -v jq &>/dev/null; then
        RESULT_TEXT=$(echo "$OUTPUT" | jq -r '.result // empty' 2>/dev/null | head -c 2000 || true)
        CYCLE_COST=$(echo "$OUTPUT" | jq -r '.total_cost_usd // empty' 2>/dev/null || true)
    fi

    if [ $EXIT_CODE -eq 0 ]; then
        log_cycle $loop_count "OK" "Completed (cost: \$${CYCLE_COST:-unknown})"
        if [ -n "$RESULT_TEXT" ]; then
            log_cycle $loop_count "SUMMARY" "$(echo "$RESULT_TEXT" | head -c 300)"
        fi
        error_count=0

    else
        error_count=$((error_count + 1))
        log_cycle $loop_count "FAIL" "Exit code $EXIT_CODE (cost: \$${CYCLE_COST:-unknown}, errors: $error_count/$MAX_CONSECUTIVE_ERRORS)"

        # Restore consensus on failure
        restore_consensus

        # Check for usage limit
        if check_usage_limit "$OUTPUT"; then
            log_cycle $loop_count "LIMIT" "API usage limit detected. Waiting ${LIMIT_WAIT_SECONDS}s..."
            save_state "waiting_limit"
            sleep $LIMIT_WAIT_SECONDS
            error_count=0
            continue
        fi

        # Circuit breaker
        if [ $error_count -ge $MAX_CONSECUTIVE_ERRORS ]; then
            log_cycle $loop_count "BREAKER" "Circuit breaker tripped! Cooling down ${COOLDOWN_SECONDS}s..."
            save_state "circuit_break"
            sleep $COOLDOWN_SECONDS
            error_count=0
            log "Circuit breaker reset. Resuming..."
        fi
    fi

    save_state "idle"
    log_cycle $loop_count "WAIT" "Sleeping ${LOOP_INTERVAL}s before next cycle..."
    sleep $LOOP_INTERVAL
done
