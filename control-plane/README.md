# Control Plane Deployment

This directory contains the configuration to deploy the Observability Control Plane on Kubernetes.

## Architecture

*   **Loki**: Central log aggregation system. Receives logs from Workers.
*   **Grafana**: Visualization dashboard.
*   **Prometheus**: Time-series database.
*   **Cloudflare Tunnel**: Exposes Loki securely so Workers can push logs without opening public ports.

## Prerequisites

1.  A Kubernetes cluster (Recommended: **k3s** for lightweight, single-node setups).
2.  `helm` installed.
3.  `kubectl` configured.

## 1. Deploy Observability Stack (Loki + Grafana)

We use the official `grafana/loki-stack` chart.

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install observability grafana/loki-stack \
  --namespace ebpf-vpc-control \
  --create-namespace \
  --values loki-stack-values.yaml
```

## 2. Expose Loki via Cloudflare Tunnel

To allow Workers (running anywhere) to push logs to this Loki instance, we deploy a Cloudflare Tunnel sidecar or ingress.

### A. Create Tunnel
On your laptop:
```bash
cloudflared tunnel create control-plane-tunnel
```

### B. Configure DNS
Route a domain (e.g., `loki.yourdomain.com`) to this tunnel.
```bash
cloudflared tunnel route dns control-plane-tunnel loki.yourdomain.com
```

### C. Deploy Tunnel Agent
Create a secret with your tunnel credentials JSON:
```bash
kubectl create secret generic tunnel-credentials \
  --from-file=credentials.json=/path/to/your/tunnel-credentials.json \
  --namespace ebpf-vpc-control
```

Apply the tunnel deployment (create `tunnel.yaml` with the content below):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: ebpf-vpc-control
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - --config
        - /etc/cloudflared/config.yaml
        - run
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared
        - name: creds
          mountPath: /etc/cloudflared/creds
          readOnly: true
      volumes:
      - name: creds
        secret:
          secretName: tunnel-credentials
      - name: config
        configMap:
          name: cloudflared-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: ebpf-vpc-control
data:
  config.yaml: |
    tunnel: <YOUR_TUNNEL_ID>
    credentials-file: /etc/cloudflared/creds/credentials.json
    ingress:
      - hostname: loki.yourdomain.com
        service: http://observability-loki:3100
      - service: http_status:404
```

## 3. Verify

1.  Get Grafana password:
    ```bash
    kubectl get secret --namespace ebpf-vpc-control observability-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
    ```
2.  Port-forward Grafana:
    ```bash
    kubectl port-forward --namespace ebpf-vpc-control service/observability-grafana 3000:80
    ```
3.  Login at `http://localhost:3000` (user: `admin`).
