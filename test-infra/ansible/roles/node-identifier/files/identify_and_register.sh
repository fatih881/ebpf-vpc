#!/bin/bash
set -e

# Path to secrets/config injected by cloud-init
CONFIG_FILE="/etc/ebpf-vpc/runner-config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file $CONFIG_FILE not found. Skipping registration."
    exit 0
fi

source "$CONFIG_FILE"

# Required vars
if [ -z "$GITHUB_URL" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_URL or GITHUB_TOKEN not set in config."
    exit 1
fi

RUNNER_DIR="/opt/actions-runner"
cd "$RUNNER_DIR"

if [ -f ".runner" ]; then
    echo "Runner already configured."
    exit 0
fi

# 1. Identify Node
# Kernel Version
KERNEL_VER=$(uname -r)

# Find primary interface
PRIMARY_IF=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
if [ -z "$PRIMARY_IF" ]; then
    PRIMARY_IF="eth0" # Fallback
fi

# Driver Info
DRIVER=$(ethtool -i "$PRIMARY_IF" | grep driver | awk '{print $2}')

# Link Speed
SPEED=$(ethtool "$PRIMARY_IF" | grep Speed | awk '{print $2}')

# PCI Address & Model
BUS_INFO=$(ethtool -i "$PRIMARY_IF" | grep bus-info | awk '{print $2}')
if [ -n "$BUS_INFO" ]; then
    MODEL=$(lspci -s "$BUS_INFO" | cut -d ':' -f3- | xargs)
    # PCIe Link Speed (LnkSta)
    # sudo lspci -vv -s ... requires privileges
    PCIE_SPEED=$(lspci -vv -s "$BUS_INFO" 2>/dev/null | grep LnkSta: | grep -o 'Speed [^,]*' | head -1 | awk '{print $2}')
else
    MODEL="Unknown"
    PCIE_SPEED="Unknown"
fi

# Sanitize Labels (replace spaces with dashes, etc)
# GitHub labels: alphanumeric, -_., start/end with alphanumeric.
sanitize() {
    local val="$1"
    # Replace anything that isn't a-z, A-Z, 0-9, ., _, or - with -
    echo "${val//[^a-zA-Z0-9._-]/}"
}

L_KERNEL="kernel-$(sanitize "$KERNEL_VER")"
L_DRIVER="driver-$(sanitize "$DRIVER")"
L_SPEED="speed-$(sanitize "$SPEED")"
L_MODEL="model-$(sanitize "$MODEL")"
L_PCIE="pcie-$(sanitize "$PCIE_SPEED")"

LABELS="self-hosted,linux,x64,$L_KERNEL,$L_DRIVER,$L_SPEED,$L_MODEL,$L_PCIE"

echo "Registering runner with labels: $LABELS"

# Write labels for Promtail
{
  echo "LOKI_LABEL_KERNEL=$L_KERNEL"
  echo "LOKI_LABEL_DRIVER=$L_DRIVER"
  echo "LOKI_LABEL_SPEED=$L_SPEED"
  echo "LOKI_LABEL_MODEL=$L_MODEL"
  echo "LOKI_LABEL_PCIE=$L_PCIE"
} > /etc/ebpf-vpc/promtail.env

# 2. Register Runner
./config.sh --unattended \
  --url "$GITHUB_URL" \
  --token "$GITHUB_TOKEN" \
  --labels "$LABELS" \
  --name "$(hostname)" \
  --replace

# 3. Install and Start Service
./svc.sh install root
./svc.sh start

# 4. Restart Promtail to pick up new labels
systemctl restart promtail
