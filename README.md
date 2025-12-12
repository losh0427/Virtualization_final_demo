# sched_ext Easy Introduction

A hands-on introduction to Linux sched_ext (eBPF-based scheduler framework) with practical demos.

[Presentation Slides](https://docs.google.com/presentation/d/1wZ7rMCfYjCfGQ_fT8Zfto0Zp4kbSHjnynjaBrgotREQ/edit?usp=sharing)

---

## Outline

- Environment Setup
- Demo 1-1: Performance Comparison
- Demo 1-2: Official Video Reference
- Demo 2: Failsafe Verification
- Repository Structure
- References

---

## Environment Setup

### Prerequisites

- Host OS: Ubuntu (or any Linux with KVM support)
- QEMU/KVM installed
- Ubuntu 25.10 ISO image

### Quick Setup Steps

```bash
# 1. Install QEMU/KVM
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

# 2. Add user to kvm group
sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER

# 3. Download Ubuntu 25.10 ISO
wget https://releases.ubuntu.com/25.10/ubuntu-25.10-live-server-amd64.iso

# 4. Create virtual disk
qemu-img create -f qcow2 ubuntu-vm.qcow2 40G

# 5. Use provided scripts
./start-vm.sh    # Start VM
./stop-vm.sh     # Stop VM
```

### VM Installation

Start VM and install Ubuntu 25.10 through VNC (localhost:5900) or console.

### SSH into VM

```bash
ssh -p 2222 user@localhost
```

### Install Dependencies in VM

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install compilation tools
sudo apt install -y build-essential clang-17 llvm-17 libbpf-dev \
    libelf-dev libssl-dev linux-headers-$(uname -r) meson ninja-build \
    cargo rustc git bpftool stress-ng sysstat bc

# Clone sched_ext schedulers
cd ~
git clone https://github.com/sched-ext/scx.git
cd scx

# Build schedulers
meson setup build -Dbuildtype=release
meson compile -C build

# Verify build
ls -lh ~/scx/build/scheds/c/scx_simple
ls -lh ~/scx/build/scheds/c/scx_central
ls -lh ~/scx/build/scheds/c/scx_flatcg
```

---

## Demo 1-1: Performance Comparison

### Objective

Compare performance of different schedulers under mixed workloads (CPU + I/O + Memory).

### Schedulers Tested

1. **EEVDF** (default, Linux 6.6+)
2. **scx_simple** (basic FIFO)
3. **scx_central** (centralized scheduling)
4. **scx_flatcg** (flattened cgroup hierarchy)

### Execution

```bash
cd ~/sched_ext_demo

# Run benchmark (tests all 4 schedulers)
./benchmark_cpu.sh

# Analyze results
cd results_*
bash ../analyze_results.sh
```

### Expected Output

```
1. Throughput (bogo ops/s)
┌─────────────┬──────────────┬──────────────┐
│ Scheduler   │ Operations/s │ vs EEVDF (%) │
├─────────────┼──────────────┼──────────────┤
│ EEVDF       │      1920.15 │       100.00 │
│ scx_simple  │      1969.56 │       102.00 │
│ scx_central │      1939.26 │       100.00 │
│ scx_flatcg  │      1982.92 │       103.00 │
└─────────────┴──────────────┴──────────────┘

2. Context Switches
┌─────────────┬──────────────┬──────────────┐
│ Scheduler   │ Total CS     │ vs EEVDF (%) │
├─────────────┼──────────────┼──────────────┤
│ EEVDF       │      5933995 │       100.00 │
│ scx_simple  │      3181616 │        53.00 │
│ scx_central │      4946391 │        83.00 │
│ scx_flatcg  │      2766658 │        46.00 │
└─────────────┴──────────────┴──────────────┘
```

---

## Demo 1-2: Official Video Reference

Watch the official sched_ext demonstration video:

🔗 [sched_ext GitHub Repository - Videos](https://github.com/sched-ext/scx)

---

## Demo 2: Failsafe Verification

### Objective

Verify sched_ext's Failsafe mechanism that prevents CrowdStrike-style system crashes.


### Execution Steps

```bash
# 1. Check initial state
cat /sys/kernel/sched_ext/state
# Output: disabled

# 2. Start scheduler (background)
sudo ~/scx/build/scheds/c/scx_simple &

# 3. Wait for initialization
sleep 2

# 4. Verify scheduler is running
cat /sys/kernel/sched_ext/state
# Output: enabled

# 5. Get scheduler PID
PID=$(pgrep scx_simple)
echo "Scheduler PID: $PID"

# 6. Simulate crash (force kill)
sudo kill -9 $PID

# 7. Observe automatic recovery
cat /sys/kernel/sched_ext/state
# Output: disabled (recovered automatically!)

# 8. Verify system is still responsive
uptime
stress-ng --cpu 2 --timeout 5s --quiet
```

### Result

 **System automatically recovered within 1 second**
- No system crash
- No manual intervention needed
- Workloads continue running

---

## Repository Structure

```
sched_ext-demo/
├── README.md                    # This file
├── start-vm.sh                  # VM startup script
├── stop-vm.sh                   # VM stop script
├── benchmark_cpu.sh             # Performance benchmark script
├── analyze_results.sh           # Results analysis script
```

---

## References

### Official Resources

- **sched_ext GitHub**: https://github.com/sched-ext/scx
- **Linux Kernel Documentation**: https://docs.kernel.org/scheduler/sched-ext.html
- **eBPF Documentation**: https://ebpf.io/

