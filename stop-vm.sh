#!/bin/bash

VM_NAME="ubuntu-sched-ext"
PID_FILE="/tmp/vm-$VM_NAME.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    echo "Stopping VM (PID: $PID)..."
    kill $PID
    sleep 2
    
    # Force kill if still running
    if kill -0 $PID 2>/dev/null; then
        kill -9 $PID
    fi
    
    rm -f "$PID_FILE"
    echo "✓ VM stopped"
else
    echo "VM not running"
fi