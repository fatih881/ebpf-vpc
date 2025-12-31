#!/bin/bash
set -e

exec 9>/var/lock/ebpf-vpc-deploy.lock
if ! flock -n 9; then
    echo "Another deployment is in progress."
    exit 1
fi

cd "$(dirname "$0")"

CONFIG_FILE="/etc/ebpf-vpc/control-plane-config.env"
VALUES_FILE="loki-stack-values.yaml"
NAMESPACE="ebpf-vpc-control"
SECRET_NAME="observability-grafana-creds"

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "Values file '$VALUES_FILE' not found."
  exit 1
fi

if [[ -f "$CONFIG_FILE" ]]; then
  if [[ -r "$CONFIG_FILE" ]]; then
    set -a
    source "$CONFIG_FILE"
    set +a
  elif command -v sudo >/dev/null 2>&1; then
    set -a
    source <(sudo cat "$CONFIG_FILE")
    set +a
  fi
fi

if [[ -z "${GRAFANA_ADMIN_PASSWORD}" ]]; then
  echo "GRAFANA_ADMIN_PASSWORD is required."
  exit 1
fi

GRAFANA_USER=${GRAFANA_ADMIN_USER:-"admin"}

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-literal=admin-user="${GRAFANA_USER}" \
  --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install observability grafana/loki-stack \
  --version 2.10.2 \
  --namespace "${NAMESPACE}" \
  --values "$VALUES_FILE"

if kubectl rollout status deployment/observability-loki -n "${NAMESPACE}" --timeout=120s; then
  echo "Deployment ready."
else
  echo "Deployment failed to become ready."
  exit 1
fi
