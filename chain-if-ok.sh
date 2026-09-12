#!/bin/bash
# Generic chain launcher: "run X once Y exits, but only if Z passes".
# Waits until a watched process (pid or pattern) exits, evaluates CHECK,
# and if CHECK exits 0 launches LAUNCH under nohup with its own log.
# Every step is appended to a status file so the outcome is traceable.
#
# Usage:
#   chain-if-ok.sh --watch-pattern REGEX | --watch-pid PID
#                  --check 'SHELL CMD (exit 0 = pass)'
#                  --launch 'SHELL CMD to run on success'
#                  [--launch-log FILE] [--name NAME] [--interval SEC]
#                  [--workdir DIR]
# Defaults: launch-log chain-if-ok_NAME_launch_YYYYmmdd_HHMM.log,
#           status     chain-if-ok_NAME_status.txt,
#           interval   60, workdir current dir.
# Example (start test split after a verified dev run, watched by name):
#   nohup bash chain-if-ok.sh \
#       --watch-pattern 'bash run_gemma_dev.sh' \
#       --check 'bash check_gemma_dev_complete.sh' \
#       --launch 'bash run_gemma_test.sh' \
#       --name gemma_test_after_dev \
#       > /dev/null 2>&1 &

set -u

WATCH_PID=""
WATCH_PATTERN=""
CHECK=""
LAUNCH=""
LAUNCH_LOG=""
NAME="unnamed"
INTERVAL=60
WORKDIR="."

while [ $# -gt 0 ]; do
    case "$1" in
        --watch-pid)    WATCH_PID="$2"; shift 2 ;;
        --watch-pattern) WATCH_PATTERN="$2"; shift 2 ;;
        --check)        CHECK="$2"; shift 2 ;;
        --launch)       LAUNCH="$2"; shift 2 ;;
        --launch-log)   LAUNCH_LOG="$2"; shift 2 ;;
        --name)         NAME="$2"; shift 2 ;;
        --interval)     INTERVAL="$2"; shift 2 ;;
        --workdir)      WORKDIR="$2"; shift 2 ;;
        *) echo "chain-if-ok: unknown argument: $1" >&2; exit 2 ;;
    esac
done

if { [ -z "$WATCH_PID" ] && [ -z "$WATCH_PATTERN" ]; } || [ -z "$CHECK" ] || [ -z "$LAUNCH" ]; then
    echo "chain-if-ok: --watch-pattern (preferred) or --watch-pid, --check and --launch are required" >&2
    exit 2
fi

cd "$WORKDIR" || exit 2
STATUS="chain-if-ok_${NAME}_status.txt"

log() { echo "[$(date '+%F %T')] $1" >> "$STATUS"; }

still_running() {
    if [ -n "$WATCH_PID" ]; then
        kill -0 "$WATCH_PID" 2>/dev/null
    else
        # exclude our own pid: the pattern occurs in this script's cmdline
        pgrep -f "$WATCH_PATTERN" | grep -vw "$$" | grep -q .
    fi
}

echo "chain-if-ok '${NAME}' started" > "$STATUS"
[ -n "$WATCH_PID" ]    && log "watching pid $WATCH_PID"
[ -n "$WATCH_PATTERN" ] && log "watching pattern '$WATCH_PATTERN'"
log "check: $CHECK"
log "launch: $LAUNCH"

while still_running; do sleep "$INTERVAL"; done
log "watched process gone"

bash -c "$CHECK" >> "$STATUS" 2>&1
check_rc=$?
if [ "$check_rc" -ne 0 ]; then
    log "CHECK FAILED (exit $check_rc) -- launch skipped"
    exit 1
fi
log "check passed"

if [ -z "$LAUNCH_LOG" ]; then
    LAUNCH_LOG="chain-if-ok_${NAME}_launch_$(date +%Y%m%d_%H%M).log"
fi
nohup bash -c "$LAUNCH" > "$LAUNCH_LOG" 2>&1 &
log "launched: pid $!, log: $LAUNCH_LOG"
