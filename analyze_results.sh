#!/bin/bash

#============================================
# Results Analysis Script
#============================================

# Find latest results directory
RESULT_DIR=$(ls -td results_* 2>/dev/null | head -1)

if [ -z "$RESULT_DIR" ] || [ ! -d "$RESULT_DIR" ]; then
    echo "Error: No results directory found"
    echo "Please run benchmark_cpu.sh first"
    exit 1
fi

cd "$RESULT_DIR"

echo "========================================="
echo "Performance Analysis Results"
echo "========================================="
echo ""

#============================================
# Extract Performance Data
#============================================

extract_bogo_ops() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "N/A"
        return
    fi
    
    # Extract bogo ops/s from stress-ng output
    local ops=$(grep "cpu " "$file" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\.[0-9]+$/) print $i}' | tail -1)
    
    if [ -z "$ops" ]; then
        echo "N/A"
    else
        echo "$ops"
    fi
}

extract_context_switches() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "N/A"
        return
    fi
    
    grep "Context Switches:" "$file" | awk '{print $3}'
}

# Collect data
EEVDF_OPS=$(extract_bogo_ops "eevdf_result.txt")
SIMPLE_OPS=$(extract_bogo_ops "scx_simple_result.txt")
CENTRAL_OPS=$(extract_bogo_ops "scx_central_result.txt")
FLATCG_OPS=$(extract_bogo_ops "scx_flatcg_result.txt")

EEVDF_CS=$(extract_context_switches "eevdf_result.txt")
SIMPLE_CS=$(extract_context_switches "scx_simple_result.txt")
CENTRAL_CS=$(extract_context_switches "scx_central_result.txt")
FLATCG_CS=$(extract_context_switches "scx_flatcg_result.txt")

#============================================
# Calculate Relative Performance
#============================================

calc_percentage() {
    local value=$1
    local baseline=$2
    
    if [ "$value" = "N/A" ] || [ "$baseline" = "N/A" ]; then
        echo "N/A"
        return
    fi
    
    echo "scale=2; ($value / $baseline) * 100" | bc
}

# Calculate relative to EEVDF
SIMPLE_PERF=$(calc_percentage "$SIMPLE_OPS" "$EEVDF_OPS")
CENTRAL_PERF=$(calc_percentage "$CENTRAL_OPS" "$EEVDF_OPS")
FLATCG_PERF=$(calc_percentage "$FLATCG_OPS" "$EEVDF_OPS")

SIMPLE_CS_PERC=$(calc_percentage "$SIMPLE_CS" "$EEVDF_CS")
CENTRAL_CS_PERC=$(calc_percentage "$CENTRAL_CS" "$EEVDF_CS")
FLATCG_CS_PERC=$(calc_percentage "$FLATCG_CS" "$EEVDF_CS")

#============================================
# Display Results
#============================================

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
echo ""

