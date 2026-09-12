#!/bin/bash
# Agentless minimal pipeline on the dev split with the local gemma model
# (llama.cpp server on :8081, model gemma4-26b-A4B-Q8_0).
# Differs from rerun_dev.sh (the qwen/gpt-qwen-coder-80b run):
#   - MODEL, RESULT_DIR are gemma-specific; qwen results untouched
#   - no rm -rf of previous results; --skip_existing provides resume
# Budgets: FL stages use FL.py self.max_tokens=2048 (300 in upstream);
# repair uses 8192 (1024 in upstream) - thinking shares the token budget.

set -e

if [ "$(basename $(pwd))" != "Agentless" ]; then
    if [ -d "Agentless" ]; then
        cd Agentless || exit 1
    else
        echo "Error: Agentless folder not found"
        exit 1
    fi
fi

export OPENAI_API_KEY=any
export OPENAI_BASE_URL=http://localhost:8081/v1
export OPENAI_TIMEOUT=3600
export PYTHONPATH=$PYTHONPATH:$(pwd)

MODEL="gemma4-26b-A4B-Q8_0"
BACKEND="openai"
DATASET="../SWEbench/data/swe-bench_lite"
SPLIT="dev"
RESULT_DIR="results/swe-bench-lite-minimal-gemma26b"
NUM_THREADS=10

mkdir -p ${RESULT_DIR}

echo "=== 1. File-level localization (${SPLIT}) ==="
python agentless/fl/localize.py \
    --file_level \
    --dataset ${DATASET} \
    --split ${SPLIT} \
    --output_folder ${RESULT_DIR}/file_level \
    --backend ${BACKEND} \
    --model ${MODEL} \
    --num_threads ${NUM_THREADS} \
    --skip_existing

echo "=== 2. Related elements ==="
python agentless/fl/localize.py \
    --related_level \
    --dataset ${DATASET} \
    --split ${SPLIT} \
    --output_folder ${RESULT_DIR}/related_elements \
    --top_n 3 \
    --compress_assign \
    --compress \
    --start_file ${RESULT_DIR}/file_level/loc_outputs.jsonl \
    --backend ${BACKEND} \
    --model ${MODEL} \
    --num_threads ${NUM_THREADS} \
    --skip_existing

echo "=== 3. Edit locations ==="
python agentless/fl/localize.py \
    --fine_grain_line_level \
    --dataset ${DATASET} \
    --split ${SPLIT} \
    --output_folder ${RESULT_DIR}/edit_location_samples \
    --top_n 3 \
    --compress \
    --temperature 0.8 \
    --num_samples 2 \
    --start_file ${RESULT_DIR}/related_elements/loc_outputs.jsonl \
    --backend ${BACKEND} \
    --model ${MODEL} \
    --num_threads ${NUM_THREADS} \
    --skip_existing

echo "=== 4. Merge edit locations ==="
python agentless/fl/localize.py \
    --merge \
    --dataset ${DATASET} \
    --split ${SPLIT} \
    --output_folder ${RESULT_DIR}/edit_location_individual \
    --top_n 3 \
    --num_samples 2 \
    --start_file ${RESULT_DIR}/edit_location_samples/loc_outputs.jsonl

echo "=== 5. Repair ==="
python agentless/repair/repair.py \
    --loc_file ${RESULT_DIR}/edit_location_individual/loc_merged_0-0_outputs.jsonl \
    --output_folder ${RESULT_DIR}/repair \
    --dataset ${DATASET} \
    --split ${SPLIT} \
    --loc_interval \
    --top_n 3 \
    --context_window 10 \
    --max_samples 5 \
    --cot \
    --diff_format \
    --gen_and_process \
    --backend ${BACKEND} \
    --model ${MODEL} \
    --num_threads 2

echo ""
echo "=== Done ==="
