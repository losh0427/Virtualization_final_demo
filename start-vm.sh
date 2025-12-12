#!/bin/bash

# VM Configuration
VM_NAME="ubuntu-sched-ext"
ISO_PATH="$HOME/qemu-vms/ubuntu-sched-ext/iso/ubuntu-25.10-live-server-amd64.iso"
DISK_PATH="$HOME/qemu-vms/ubuntu-sched-ext/disks/ubuntu-sched-ext.qcow2"

# Resources
VCPUS=4
MEMORY=8192
VNC_PORT=5900
SSH_PORT=2222

echo "Starting VM: $VM_NAME"
echo "VNC: localhost:$VNC_PORT"
echo "SSH: ssh -p $SSH_PORT user@localhost"

qemu-system-x86_64 \
    -name "$VM_NAME" \
    -machine type=q35,accel=kvm \
    -cpu host \
    -smp cpus=$VCPUS \
    -m $MEMORY \
    -drive file="$DISK_PATH",if=virtio,cache=writeback,discard=unmap \
    -cdrom "$ISO_PATH" \
    -boot order=d \
    -vnc :0 \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::$SSH_PORT-:22 \
    -display none \
    -daemonize \
    -pidfile /tmp/vm-$VM_NAME.pid

echo "✓ VM started"