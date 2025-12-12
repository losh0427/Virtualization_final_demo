#!/bin/bash

# Get the real user's home directory (even when run with sudo)
if [ -n "$SUDO_USER" ]; then
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_HOME=$HOME
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEST_DURATION=30  # seconds
RESULT_DIR="results_$(date +%Y%m%d_%H%M%S)"

# Mixed workload configuration
CPU_WORKERS=2
IO_WORKERS=2
VM_WORKERS=1
VM_BYTES="128M"

# Scheduler paths (use real user's home)
SCX_SIMPLE="$REAL_HOME/scx/build/scheds/c/scx_simple"
SCX_CENTRAL="$REAL_HOME/scx/build/scheds/c/scx_central"
SCX_FLATCG="$REAL_HOME/scx/build/scheds/c/scx_flatcg"

# Scheduler list
SCHEDULERS=("default" "scx_simple" "scx_central" "scx_flatcg")

#============================================
# Helper Functions
#============================================

print_header() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

print_section() {
    echo -e "${YELLOW}-----------------------------------${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}-----------------------------------${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to check if scheduler is enabled
is_scheduler_enabled() {
    if [ -f /sys/kernel/sched_ext/state ]; then
        local state=$(cat /sys/kernel/sched_ext/state)
        if [ "$state" = "enabled" ]; then
            return 0  # Success - scheduler is enabled
        else
            return 1  # Scheduler is not enabled
        fi
    else
        return 1  # sched_ext not supported
    fi
}

# Function to start monitoring
start_monitoring() {
    local log_file=$1
    # Start mpstat in background
    mpstat 1 > "${log_file}" 2>&1 &
    echo $!
}

# Function to stop monitoring
stop_monitoring() {
    local pid=$1
    if [ -n "$pid" ]; then
        kill $pid 2>/dev/null || true
        wait $pid 2>/dev/null || true
    fi
}

# Function to extract context switches
get_context_switches() {
    local start_file=$1
    local end_file=$2
    
    if [ ! -f "$start_file" ] || [ ! -f "$end_file" ]; then
        echo "N/A"
        return
    fi
    
    local start_cs=$(grep "^ctxt" "$start_file" | awk '{print $2}')
    local end_cs=$(grep "^ctxt" "$end_file" | awk '{print $2}')
    
    if [ -z "$start_cs" ] || [ -z "$end_cs" ]; then
        echo "N/A"
        return
    fi
    
    echo $((end_cs - start_cs))
}

#============================================
# Test Execution
#============================================

run_test() {
    local scheduler=$1
    local test_name=$2
    local result_file="${RESULT_DIR}/${test_name}_result.txt"
    local monitor_file="${RESULT_DIR}/${test_name}_monitor.txt"
    local stat_start="${RESULT_DIR}/${test_name}_stat_start.txt"
    local stat_end="${RESULT_DIR}/${test_name}_stat_end.txt"
    
    print_section "Test: $test_name"
    
    # Start scheduler if needed
    local sched_pid=""
    if [ "$scheduler" != "default" ]; then
        echo "Starting scheduler: $scheduler"
        
        case $scheduler in
            scx_simple)
                sudo $SCX_SIMPLE &
                ;;
            scx_central)
                sudo $SCX_CENTRAL &
                ;;
            scx_flatcg)
                sudo $SCX_FLATCG &
                ;;
        esac
        
        sched_pid=$!
        sleep 2  # Wait for scheduler to initialize
        
        # Verify scheduler is running
        if ! is_scheduler_enabled; then
            print_error "Failed to start $scheduler (state not enabled)"
            return 1
        fi
        echo "Scheduler active: $scheduler (state: enabled)"
    else
        echo "Using default scheduler (EEVDF)"
    fi
    
    # Record start time and stats
    echo "Start time: $(date)" | tee "$result_file"
    cat /proc/stat > "$stat_start"
    
    # Start monitoring
    local monitor_pid=$(start_monitoring "$monitor_file")
    
    # Run stress-ng with mixed workload
    echo "Running mixed workload test for ${TEST_DURATION}s..."
    echo "  CPU workers: 2"
    echo "  I/O workers: 2"
    echo "  Memory workers: 1"
    stress-ng --cpu 2 \
              --io 2 \
              --vm 1 \
              --vm-bytes 128M \
              --timeout ${TEST_DURATION}s \
              --metrics-brief 2>&1 | tee -a "$result_file"
    
    # Stop monitoring
    stop_monitoring $monitor_pid
    
    # Record end time and stats
    cat /proc/stat > "$stat_end"
    echo "End time: $(date)" | tee -a "$result_file"
    
    # Calculate context switches
    local cs=$(get_context_switches "$stat_start" "$stat_end")
    echo "Context Switches: $cs" | tee -a "$result_file"
    
    # Stop scheduler if running
    if [ -n "$sched_pid" ]; then
        echo "Stopping scheduler..."
        sudo kill $sched_pid 2>/dev/null || true
        sleep 2
    fi
    
    print_success "$test_name test completed"
    echo ""
}

#============================================
# Main Execution
#============================================

main() {
    print_header "Demo 2: Mixed Workload Performance Test"
    
    echo "Test Configuration:"
    echo "  CPU workers: $CPU_WORKERS"
    echo "  I/O workers: $IO_WORKERS"
    echo "  Memory workers: $VM_WORKERS (${VM_BYTES} each)"
    echo "  Test Duration: ${TEST_DURATION}s per scheduler"
    echo "  Results Directory: $RESULT_DIR"
    echo ""
    
    # Create result directory
    mkdir -p "$RESULT_DIR"
    
    # Verify all schedulers are available
    echo "Checking scheduler availability..."
    if [ ! -x "$SCX_SIMPLE" ]; then
        print_error "scx_simple not found at $SCX_SIMPLE"
        exit 1
    fi
    if [ ! -x "$SCX_CENTRAL" ]; then
        print_error "scx_central not found at $SCX_CENTRAL"
        exit 1
    fi
    if [ ! -x "$SCX_FLATCG" ]; then
        print_error "scx_flatcg not found at $SCX_FLATCG"
        exit 1
    fi
    print_success "All schedulers available"
    echo ""
    
    # Run tests for each scheduler
    local test_num=1
    local total_tests=${#SCHEDULERS[@]}
    
    for sched in "${SCHEDULERS[@]}"; do
        print_header "Test $test_num/$total_tests: $sched"
        
        case $sched in
            default)
                run_test "default" "eevdf"
                ;;
            scx_simple)
                run_test "scx_simple" "scx_simple"
                ;;
            scx_central)
                run_test "scx_central" "scx_central"
                ;;
            scx_flatcg)
                run_test "scx_flatcg" "scx_flatcg"
                ;;
        esac
        
        ((test_num++))
        
        # Wait between tests
        if [ $test_num -le $total_tests ]; then
            echo "Waiting 5 seconds before next test..."
            sleep 5
        fi
    done
    
    print_header "All Tests Completed"
    echo ""
    echo "Results saved in: $RESULT_DIR"
    echo ""
    echo "To analyze results:"
    echo "  cd $RESULT_DIR"
    echo "  cat ../analyze_results.sh | bash"
}
