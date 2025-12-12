#!/bin/bash

# VM 配置
VM_NAME="ubuntu-sched-ext"
ISO_PATH="$HOME/qemu-vms/ubuntu-sched-ext/iso/ubuntu-25.10-live-server-amd64.iso"
DISK_PATH="$HOME/qemu-vms/ubuntu-sched-ext/disks/ubuntu-sched-ext.qcow2"

# 資源配置
VCPUS=4          # 虛擬 CPU 核心數（根據你的 server 調整）
MEMORY=8192      # RAM (MB)，8GB
VNC_PORT=5900    # VNC 端口

# 網路配置
NET_TYPE="user"  # user mode networking (NAT)
SSH_PORT=2222    # Host 的 2222 port 轉發到 VM 的 22 port

echo "Starting VM: $VM_NAME"
echo "VCPUs: $VCPUS"
echo "Memory: ${MEMORY}MB"
echo "VNC: localhost:$VNC_PORT (display :0)"
echo "SSH: ssh -p $SSH_PORT username@localhost"
echo ""

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
