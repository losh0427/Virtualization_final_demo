#!/bin/bash

# Find latest results directory
RESULT_DIR=$(ls -td results_* 2>/dev/null | head -1)

[ -z "$RESULT_DIR" ] && echo "Error: No results found" && exit 1

cd "$RESULT_DIR"

echo "========================================="
echo "Performance Analysis Results"
echo "========================================="
echo ""

# Extract data
extract_ops() {
    grep "cpu " "$1" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\.[0-9]+$/) print $i}' | tail -1
}

extract_cs() {
    grep "Context Switches:" "$1" | awk '{print $3}'
}

# Collect data
EEVDF_OPS=$(extract_ops "eevdf_result.txt")
SIMPLE_OPS=$(extract_ops "scx_simple_result.txt")
CENTRAL_OPS=$(extract_ops "scx_central_result.txt")
FLATCG_OPS=$(extract_ops "scx_flatcg_result.txt")

EEVDF_CS=$(extract_cs "eevdf_result.txt")
SIMPLE_CS=$(extract_cs "scx_simple_result.txt")
CENTRAL_CS=$(extract_cs "scx_central_result.txt")
FLATCG_CS=$(extract_cs "scx_flatcg_result.txt")

# Calculate percentages
calc_perc() {
    echo "scale=2; ($1 / $2) * 100" | bc
}

SIMPLE_PERF=$(calc_perc "$SIMPLE_OPS" "$EEVDF_OPS")
CENTRAL_PERF=$(calc_perc "$CENTRAL_OPS" "$EEVDF_OPS")
FLATCG_PERF=$(calc_perc "$FLATCG_OPS" "$EEVDF_OPS")

SIMPLE_CS_PERC=$(calc_perc "$SIMPLE_CS" "$EEVDF_CS")
CENTRAL_CS_PERC=$(calc_perc "$CENTRAL_CS" "$EEVDF_CS")
FLATCG_CS_PERC=$(calc_perc "$FLATCG_CS" "$EEVDF_CS")

# Display results
echo "1. Throughput (bogo ops/s)"
echo "┌─────────────┬──────────────┬──────────────┐"
echo "│ Scheduler   │ Operations/s │ vs EEVDF (%) │"
echo "├─────────────┼──────────────┼──────────────┤"
printf "│ %-11s │ %12s │ %12s │\n" "EEVDF" "$EEVDF_OPS" "100.00"
printf "│ %-11s │ %12s │ %12s │\n" "scx_simple" "$SIMPLE_OPS" "$SIMPLE_PERF"
printf "│ %-11s │ %12s │ %12s │\n" "scx_central" "$CENTRAL_OPS" "$CENTRAL_PERF"
printf "│ %-11s │ %12s │ %12s │\n" "scx_flatcg" "$FLATCG_OPS" "$FLATCG_PERF"
echo "└─────────────┴──────────────┴──────────────┘"
echo ""

echo "2. Context Switches"
echo "┌─────────────┬──────────────┬──────────────┐"
echo "│ Scheduler   │ Total CS     │ vs EEVDF (%) │"
echo "├─────────────┼──────────────┼──────────────┤"
printf "│ %-11s │ %12s │ %12s │\n" "EEVDF" "$EEVDF_CS" "100.00"
printf "│ %-11s │ %12s │ %12s │\n" "scx_simple" "$SIMPLE_CS" "$SIMPLE_CS_PERC"
printf "│ %-11s │ %12s │ %12s │\n" "scx_central" "$CENTRAL_CS" "$CENTRAL_CS_PERC"
printf "│ %-11s │ %12s │ %12s │\n" "scx_flatcg" "$FLATCG_CS" "$FLATCG_CS_PERC"
echo "└─────────────┴──────────────┴──────────────┘"