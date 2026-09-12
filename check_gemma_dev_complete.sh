#!/bin/bash
# Success check for the gemma DEV Agentless run (run_gemma_dev.sh).
# Exit 0 iff every stage produced its expected artifacts:
#   - dev log ends with the '=== Done ===' marker (set -e guarantees no
#     stage failure can reach it)
#   - 23 lines in file_level / related_elements / edit_location_samples
#   - non-empty merged localization loc_merged_0-0_outputs.jsonl
#   - repair sample 4 processed (all 5 repair samples completed), 23 lines
# Expected counts follow the completed qwen dev run.

DEV_DIR=results/swe-bench-lite-minimal-gemma26b
DEV_LOG=$(ls -t gemma26b_dev_run_*.log 2>/dev/null | head -1)

fail=0

if [ -z "$DEV_LOG" ]; then
    echo "check_gemma_dev_complete: no gemma26b_dev_run_*.log found"; fail=1
elif ! grep -q '=== Done ===' "$DEV_LOG"; then
    echo "check_gemma_dev_complete: no '=== Done ===' marker in $DEV_LOG"; fail=1
fi

for stage in file_level related_elements edit_location_samples; do
    f="$DEV_DIR/$stage/loc_outputs.jsonl"
    n=$(wc -l < "$f" 2>/dev/null || echo 0)
    [ "$n" -eq 23 ] || { echo "check_gemma_dev_complete: $f has $n lines (expected 23)"; fail=1; }
done

f="$DEV_DIR/edit_location_individual/loc_merged_0-0_outputs.jsonl"
[ -s "$f" ] || { echo "check_gemma_dev_complete: $f missing or empty"; fail=1; }

f="$DEV_DIR/repair/output_4_processed.jsonl"
n=$(wc -l < "$f" 2>/dev/null || echo 0)
[ "$n" -eq 23 ] || { echo "check_gemma_dev_complete: $f has $n lines (expected 23)"; fail=1; }

[ "$fail" -eq 0 ] && echo "check_gemma_dev_complete: all dev artifacts OK"
exit "$fail"
