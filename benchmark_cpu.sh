#!/bin/bash

# Get real user home directory
if [ -n "$SUDO_USER" ]; then
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_HOME=$HOME
fi

# Configuration
TEST_DURATION=30
RESULT_DIR="results_$(date +%Y%m%d_%H%M%S)"

# Scheduler paths
SCX_SIMPLE="$REAL_HOME/scx/build/scheds/c/scx_simple"
SCX_CENTRAL="$REAL_HOME/scx/build/scheds/c/scx_central"
SCX_FLATCG="$REAL_HOME/scx/build/scheds/c/scx_flatcg"

SCHEDULERS=("default" "scx_simple" "scx_central" "scx_flatcg")

# Check if scheduler is enabled
is_scheduler_enabled() {
    [ -f /sys/kernel/sched_ext/state ] && [ "$(cat /sys/kernel/sched_ext/state)" = "enabled" ]
}

# Start monitoring
start_monitoring() {
    mpstat 1 > "$1" 2>&1 &
    echo $!
}

# Stop monitoring
stop_monitoring() {
    kill $1 2>/dev/null
    wait $1 2>/dev/null
}

# Get context switches
get_context_switches() {
    local start_cs=$(grep "^ctxt" "$1" | awk '{print $2}')
    local end_cs=$(grep "^ctxt" "$2" | awk '{print $2}')
    echo $((end_cs - start_cs))
}

# Run test
run_test() {
    local scheduler=$1
    local test_name=$2
    local result_file="${RESULT_DIR}/${test_name}_result.txt"
    local monitor_file="${RESULT_DIR}/${test_name}_monitor.txt"
    local stat_start="${RESULT_DIR}/${test_name}_stat_start.txt"
    local stat_end="${RESULT_DIR}/${test_name}_stat_end.txt"
    
    echo "=== Test: $test_name ==="
    
    # Start scheduler if needed
    local sched_pid=""
    if [ "$scheduler" != "default" ]; then
        case $scheduler in
            scx_simple)  sudo $SCX_SIMPLE & ;;
            scx_central) sudo $SCX_CENTRAL & ;;
            scx_flatcg)  sudo $SCX_FLATCG & ;;
        esac
        sched_pid=$!
        sleep 2
    fi
    
    # Record start
    date > "$result_file"
    cat /proc/stat > "$stat_start"
    
    # Start monitoring
    local monitor_pid=$(start_monitoring "$monitor_file")
    
    # Run workload
    stress-ng --cpu 2 --io 2 --vm 1 --vm-bytes 128M --timeout ${TEST_DURATION}s --metrics-brief 2>&1 | tee -a "$result_file"
    
    # Stop monitoring
    stop_monitoring $monitor_pid
    
    # Record end
    cat /proc/stat > "$stat_end"
    date >> "$result_file"
    
    # Calculate context switches
    echo "Context Switches: $(get_context_switches "$stat_start" "$stat_end")" >> "$result_file"
    
    # Stop scheduler
    [ -n "$sched_pid" ] && sudo kill $sched_pid 2>/dev/null && sleep 2
    
    echo ""
}

# Main
mkdir -p "$RESULT_DIR"

for sched in "${SCHEDULERS[@]}"; do
    case $sched in
        default)     run_test "default" "eevdf" ;;
        scx_simple)  run_test "scx_simple" "scx_simple" ;;
        scx_central) run_test "scx_central" "scx_central" ;;
        scx_flatcg)  run_test "scx_flatcg" "scx_flatcg" ;;
    esac
    sleep 5
done

echo "Results saved in: $RESULT_DIR"
echo "To analyze: cd $RESULT_DIR && bash ../analyze_results.sh"