#!/bin/bash
# RFC Requirement: Node Identification & Runner Registration
# This script runs as a systemd service on boot/network-online

RUNNER_NAME=$(hostname)
RUNNER_USER="github-runner"
RUNNER_DIR="/actions-runner"
LABELS="self-hosted,linux,x64,baremetal"

# Gather Metrics
KERNEL_REL=$(uname -r)
# Assuming primary non-loopback/non-management interface for tagging
# In production, this logic might need specific targeting based on management network exclusion
TARGET_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo" | head -n 1)

if [ -n "$TARGET_IFACE" ]; then
    DRIVER=$(ethtool -i "$TARGET_IFACE" | grep driver | awk '{print $2}')
    FW_VER=$(ethtool -i "$TARGET_IFACE" | grep firmware | awk '{print $2}')
    NIC_MODEL=$(lspci | grep -i eth | head -n 1 | cut -d: -f3-)
    
    # Sanitize for labels
    DRIVER_LABEL="driver=${DRIVER}"
    FW_LABEL="fw=${FW_VER// /_}"
    KERNEL_LABEL="kernel=${KERNEL_REL// /_}"
    
    LABELS="${LABELS},${DRIVER_LABEL},${FW_LABEL},${KERNEL_LABEL},perf-baremetal"
fi

# RFC: Benchmark Support - Check if this is a perf runner
# We add the 'perf-baremetal' label implicitly above for this env, 
# or strictly if specific hardware conditions are met.

echo "Registering runner with labels: $LABELS"

# Registration logic (Idempotent check)
if [ ! -f "$RUNNER_DIR/.runner" ]; then
    # RFC: Secrets injected at runtime. 
    # Expecting RUNNER_TOKEN to be available in environment from /etc/runner-config.env or similar injected source
    if [ -f "/etc/runner-config.env" ]; then
        source /etc/runner-config.env
    fi

    if [ -z "$RUNNER_TOKEN" ] || [ -z "$REPO_URL" ]; then
        echo "Missing RUNNER_TOKEN or REPO_URL. Skipping registration."
        exit 1
    fi

    cd $RUNNER_DIR
    sudo -u $RUNNER_USER ./config.sh \
        --url "$REPO_URL" \
        --token "$RUNNER_TOKEN" \
        --name "$RUNNER_NAME" \
        --labels "$LABELS" \
        --unattended \
        --replace
fi
