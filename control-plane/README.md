# Control Plane Deployment

This directory contains the configuration to deploy the Observability Control Plane on Kubernetes.

## Architecture

*   **Loki**: Central log aggregation system. Receives logs from Workers.
*   **Grafana**: Visualization dashboard.
*   **Prometheus**: Time-series database.
*   **Cloudflare Tunnel**: Exposes Loki securely so Workers can push logs without opening public ports.

## Prerequisites

1.  A Kubernetes cluster (Recommended: **k3s** for lightweight, single-node setups).
    *   Kubernetes/k3s: `>=1.24`
2.  `helm` installed.
    *   `helm`: `>=3.10`
3.  `kubectl` configured.
    *   `kubectl`: Compatible with your cluster version.

## 1. Deploy Observability Stack (Loki + Grafana)

Use the zero-touch deployment script. This script handles namespace creation, secret management, and Helm deployment.

It requires `GRAFANA_ADMIN_PASSWORD` to be set via environment variable or in `/etc/ebpf-vpc/control-plane-config.env`.

```bash
# Run the deployment
./deploy.sh
```

### 1.1. Verification and Troubleshooting

**CRITICAL:** Ensure the observability stack is fully deployed and healthy before proceeding to Step 2.

Run the following checks. If resources are missing or pods are failing, troubleshoot using the logs command and do not proceed until resolved.

```bash
# Verify namespace exists
kubectl get namespace ebpf-vpc-control

# Verify Loki service exists
kubectl get svc observability-loki -n ebpf-vpc-control

# Verify pod readiness
kubectl get pods --namespace ebpf-vpc-control

# Review logs if pods fail
kubectl logs -n ebpf-vpc-control -l app.kubernetes.io/name=loki
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

### Verify Secret Creation

Verify the secret was created successfully:

```bash
kubectl get secret tunnel-credentials -n ebpf-vpc-control
```

### Validate Credentials Content

Validate the credentials file content (requires `jq` to be installed):

```bash
kubectl get secret tunnel-credentials -n ebpf-vpc-control -o jsonpath='{.data.credentials\.json}' | base64 -d | jq .
```

Apply the tunnel deployment (create `tunnel.yaml` with the content below):

```bash
# Ensure placeholders are replaced
grep -E '<YOUR_TUNNEL_ID>|yourdomain\.com' tunnel.yaml && \
  echo "ERROR: Placeholders detected! Replace before applying." && \
  exit 1

# Apply only after validation
kubectl apply -f tunnel.yaml
```

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
        image: cloudflare/cloudflared:2025.11.1
        args:
        - tunnel
        - --config
        - /etc/cloudflared/config.yaml
        - --metrics
        - 0.0.0.0:8080
        - run
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared
        - name: creds
          mountPath: /etc/cloudflared/creds
          readOnly: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /ready
            port: 8080 # Default cloudflared metrics port
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        securityContext:
          runAsNonRoot: true
          runAsUser: 65532 # nobody user
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

## 3. Verify

This section outlines comprehensive verification steps to ensure the observability stack is fully functional.

1.  **Verify Cloudflare Tunnel connectivity from an external source** (replace `loki.yourdomain.com` with your configured domain):

    *Note: DNS propagation can take minutes to hours. If the command fails, verify resolution with `dig loki.yourdomain.com` or use a manual hosts entry. Retry after propagation.*

    ```bash
    curl -X POST https://loki.yourdomain.com/loki/api/v1/push \
      -H "Content-Type: application/json" \
      -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s)000000000'","test message"]]}]}'
    ```

2.  **Verify Loki storage** (check if logs are being persisted):
    ```bash
    kubectl exec -n ebpf-vpc-control deployment/observability-loki -- \
      du -sh /loki
    ```

3.  **Test Grafana datasource connectivity** (port-forward and check from browser):
    ```bash
    kubectl port-forward --namespace ebpf-vpc-control service/observability-grafana 3000:80 &
    ```
    Then, navigate to `http://localhost:3000` in your browser, log in (get password with `kubectl get secret --namespace ebpf-vpc-control observability-grafana -o jsonpath="{.data.admin-password}" | base64 --decode`), and navigate to Explore > Loki > Query logs.