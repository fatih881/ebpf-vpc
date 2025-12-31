# Infrastructure Deployment Guide

This document outlines the steps to build, configure, and deploy the CI/CD infrastructure for repository.

## 1. Prerequisites

Ensure the following tools are installed on your workstation or build machine:

*   **Packer** 
*   **Ansible** 
*   **QEMU / KVM** (for local testing,optional)
*   **genisoimage** (or `mkisofs`) for creating cloud-init seeds
*   **Cloudflare Account** (for Tunnel token)
*   **GitHub Repository Admin Access** (for Runner registration token)

## 2. Building the Golden Image

We use HashiCorp Packer to bake an immutable Fedora image with all necessary dependencies pre-installed.

### A. Local Build
1.  Navigate to the packer directory:
    ```bash
    cd test-infra/packer
    ```
2.  Build the image:
    ```bash
    packer init fedora.pkr.hcl
    packer build fedora.pkr.hcl
    ```

### B. Cloud Build (Recommended)
For consistent builds, use a dedicated **Build VM** in the cloud (e.g., AWS EC2 Metal, Packet/Equinix Metal, or a nested virtualization capable instance).

1.  Provision a VM with KVM support.
2.  Clone the repository.
3.  Run the Packer build as shown in the Local Build section.
4.  Upload the resulting `qcow2` image to your object storage (S3, MinIO) or convert it to an AMI/Cloud Image if targeting virtualized fleets.

## 3. Runtime Configuration (Secrets)

The image is immutable and contains **no secrets**. All configuration is injected at runtime via `cloud-init`.

You must provide a `user-data` file that writes the sensitive configuration to `/etc/ebpf-vpc/runner-config.env`.

### Example `user-data`

```yaml
#cloud-config
users:
  - name: fedora
    ssh_authorized_keys:
      - ssh-rsa AAAAB3Nza... your-public-key ...

write_files:
  - path: /etc/ebpf-vpc/runner-config.env
    permissions: '0400'
    owner: root:root
    content: |
      GITHUB_URL="https://github.com/fatih881/ebpf-vpc"
      GITHUB_TOKEN="A_VALID_GITHUB_RUNNER_REGISTRATION_TOKEN"
      CLOUDFLARE_TUNNEL_TOKEN="your-cloudflare-tunnel-token"
      LOKI_URL="https://loki.your-domain.com/loki/api/v1/push"

runcmd:
  - mkdir -p /etc/ebpf-vpc
```

## 4. Deployment

### Method A: QEMU / Local Testing

1.  **Generate Seed ISO**:
    ```bash
    genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
    ```

2.  **Boot Image**:
    ```bash
    qemu-system-x86_64 \
      -name <VM_NAME> \
      -m <MEMORY_SIZE> \
      -smp <CPU_CORES> \
      -enable-kvm \
      -net nic,model=virtio -net user \
      -drive file=test-infra/packer/output-fedora-nocloud/fedora-nocloud.qcow2,if=virtio \
      -drive file=seed.iso,format=raw,if=virtio
    ```

### Method B: Bare Metal

For bare metal deployment, avoid manual media. Use **iPXE** or **BMC/Redfish Virtual Media**.

1.  **Image Serving**: Host the `qcow2` (or converted raw image) and the `user-data` on an internal web server.
2.  **Booting**:
    *   **iPXE**: Chainload into a kernel/initrd that pulls the system image to RAM or disk, providing the `ds=nocloud-net;s=http://<metadata-server>/` kernel argument.
    *   **BMC Virtual Media**: Mount the `seed.iso` (containing user-data) via Redfish API as a virtual CD-ROM, and flash the OS image to the local disk via a provisioner (like Tinkerbell, MAAS, or a custom discovery agent).

## 5. Verification

Once booted:
1.  **SSH**: `ssh fedora@<IP>`
2.  **Services**: `systemctl status node-identifier`
3.  **Observability**: Verify logs in Loki with labels `host=<hostname>`, `driver=<nic_driver>`.