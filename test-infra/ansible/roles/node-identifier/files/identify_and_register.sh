#!/bin/bash
set -e

CONFIG_FILE="/etc/ebpf-vpc/runner-config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

source "$CONFIG_FILE"

if [ -z "$GITHUB_URL" ] || [ -z "$GITHUB_TOKEN" ]; then
    exit 1
fi

RUNNER_DIR="/opt/actions-runner"
cd "$RUNNER_DIR"

if [ -f ".runner" ]; then
    exit 0
fi

KERNEL_VER=$(uname -r)

U_DRIVERS=""
U_MODELS=""
U_SPEEDS=""
U_PCIE=""

sanitize() {
    local val="$1"
    echo "${val//[^a-zA-Z0-9._-]/}"
}

append_unique() {
    local list="$1"
    local new="$2"
    if [[ ! " $list " =~ " $new " ]]; then
        echo "$list $new"
    else
        echo "$list"
    fi
}

for iface_path in /sys/class/net/*; do
    iface=$(basename "$iface_path")
    
    if [ "$iface" == "lo" ]; then continue; fi
    if [ ! -L "$iface_path/device" ]; then continue; fi

    drv=$(ethtool -i "$iface" 2>/dev/null | grep driver | awk '{print $2}')
    if [ -n "$drv" ]; then
        U_DRIVERS=$(append_unique "$U_DRIVERS" "$drv")
    fi

    spd=$(ethtool "$iface" 2>/dev/null | grep Speed | awk '{print $2}')
    if [ -n "$spd" ]; then
        U_SPEEDS=$(append_unique "$U_SPEEDS" "$spd")
    fi

    bus_info=$(ethtool -i "$iface" 2>/dev/null | grep bus-info | awk '{print $2}')
    if [ -n "$bus_info" ]; then
        mdl=$(lspci -s "$bus_info" 2>/dev/null | cut -d ':' -f3- | xargs)
        if [ -n "$mdl" ]; then
            U_MODELS=$(append_unique "$U_MODELS" "$mdl")
        fi
        
        lnk=$(lspci -vv -s "$bus_info" 2>/dev/null | grep LnkSta: | grep -o 'Speed [^,]*' | head -1 | awk '{print $2}')
        if [ -n "$lnk" ]; then
            U_PCIE=$(append_unique "$U_PCIE" "$lnk")
        fi
    fi
done

L_KERNEL="kernel-$(sanitize "$KERNEL_VER")"

L_DRIVERS=""
for i in $U_DRIVERS; do
    l="driver-$(sanitize "$i")"
    if [ -z "$L_DRIVERS" ]; then L_DRIVERS="$l"; else L_DRIVERS="$L_DRIVERS,$l"; fi
done

L_SPEEDS=""
for i in $U_SPEEDS; do
    l="speed-$(sanitize "$i")"
    if [ -z "$L_SPEEDS" ]; then L_SPEEDS="$l"; else L_SPEEDS="$L_SPEEDS,$l"; fi
done

L_MODELS=""
for i in $U_MODELS; do
    l="model-$(sanitize "$i")"
    if [ -z "$L_MODELS" ]; then L_MODELS="$l"; else L_MODELS="$L_MODELS,$l"; fi
done

L_PCIE=""
for i in $U_PCIE; do
    l="pcie-$(sanitize "$i")"
    if [ -z "$L_PCIE" ]; then L_PCIE="$l"; else L_PCIE="$L_PCIE,$l"; fi
done

LABELS="self-hosted,linux,x64,$L_KERNEL,$L_DRIVERS,$L_SPEEDS,$L_MODELS,$L_PCIE"

{
  echo "LOKI_LABEL_KERNEL=$L_KERNEL"
  echo "LOKI_LABEL_DRIVERS=$L_DRIVERS"
  echo "LOKI_LABEL_SPEED=$L_SPEEDS"
  echo "LOKI_LABEL_MODEL=$L_MODELS"
  echo "LOKI_LABEL_PCIE=$L_PCIE"
} > /etc/ebpf-vpc/promtail.env

RUNNER_USER="fedora"
chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

runuser -u "$RUNNER_USER" -- ./config.sh --unattended \
  --url "$GITHUB_URL" \
  --token "$GITHUB_TOKEN" \
  --labels "$LABELS" \
  --name "$(hostname)" \
  --replace

./svc.sh install "$RUNNER_USER"
./svc.sh start

systemctl restart promtail
