#!/bin/bash
set -e

# RFC Requirement: Environment Hygiene
# Usage: ./ebpf-cleanup.sh <interface_name>

IFACE=$1

if [ -z "$IFACE" ]; then
    echo "Usage: $0 <interface_name>"
    exit 1
fi

# 1. Remove all pinned BPF programs and maps
if [ -d "/sys/fs/bpf" ]; then
    find /sys/fs/bpf -mindepth 1 -delete
    echo "Cleaned /sys/fs/bpf"
fi

# 2. Reset NIC State
# RFC Safety: Use devlink or ip link, avoid modprobe -r
if command -v devlink &> /dev/null; then
    echo "Attempting devlink reload for $IFACE..."
    # Capture bus info for devlink
    BUS_INFO=$(ethtool -i "$IFACE" | grep bus-info | awk '{print $2}')
    if [ ! -z "$BUS_INFO" ]; then
        devlink dev reload "pci/$BUS_INFO" || echo "devlink reload failed, falling back to link reset"
    fi
fi

# Fallback/Additional: Link flap to clear some HW states
ip link set dev "$IFACE" down
ip link set dev "$IFACE" up

echo "Cleanup complete for $IFACE"
