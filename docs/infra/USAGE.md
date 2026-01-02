# Infrastructure Usage Guide

This guide describes how to build, test, and deploy the immutable test infrastructure image.

## Prerequisites

- **Packer**: v1.8+
- **Ansible**: v2.10+
- **QEMU/KVM**: Required for local testing and running built images.
- **genisoimage** (or `mkisofs`): Required to create the seed ISO for local testing.

## Building the Image

To build the Fedora-based test image:

```bash
cd test-infra/packer
packer init fedora.pkr.hcl
packer build fedora.pkr.hcl
```

This will produce a `fedora-nocloud.qcow2` image in the `output-fedora-nocloud` directory.

## Running Locally (QEMU)

To test the image locally, you need to provide a cloud-init data source (NoCloud).

1.  **Create a seed ISO** containing `user-data` and `meta-data`:

    The default `test-infra/packer/config/user-data` locks the password and disables SSH password authentication. To log in locally, you must either:
    
    *   **Option A (Recommended)**: Create a `user-data.local` file with the following content to enable password login:
        ```yaml
        #cloud-config
        users:
          - name: fedora
            lock_passwd: false
            passwd: $6$rounds=4096$salt$hashed_password # Generate with: mkpasswd -m sha-512
            sudo: ['ALL=(ALL) NOPASSWD:ALL']
            shell: /bin/bash
        ssh_pwauth: true
        ```
        Then use `user-data.local` in the command below.
    *   **Option B**: Modify `test-infra/packer/config/user-data` directly to set `lock_passwd: false`, `ssh_pwauth: true`, and provide a `passwd` hash.

    ```bash
    genisoimage -output seed.iso -volid cidata -joliet -rock \
        user-data.local \
        test-infra/packer/config/meta-data
    ```

2.  **Boot the image with QEMU**:

    ```bash
    qemu-system-x86_64 \
        -m 2048 \
        -smp 2 \
        -drive file=output-fedora-nocloud/fedora-nocloud.qcow2,format=qcow2,if=virtio \
        -drive file=seed.iso,format=raw,if=virtio \
        -net nic,model=virtio -net user,hostfwd=tcp::2222-:22 \
        -nographic
    ```

3.  **SSH into the VM**:

    ```bash
    ssh -p 2222 fedora@localhost
    ```

## Cloud Deployment

This image is designed to be cloud-agnostic but optimized for KVM-based environments.

### Uploading to Cloud Providers

1.  **AWS**: Import the `qcow2` as an AMI using `aws ec2 import-image`.
2.  **GCP**: Upload to Cloud Storage and create an image using `gcloud compute images create`.
3.  **OpenStack/Private Cloud**: Upload to Glance.

### CI/CD Recommendations

For automated pipelines, we recommend the following workflow to ensure security and efficiency:

1.  **Ephemeral Build Environment**: Run the Packer build on a temporary, isolated instance (e.g., a GitHub Actions runner or a dedicated build VM).
2.  **Artifact Storage**:
    - Do **not** store large images in Git.
    - Upload the built `qcow2` to a secure object storage service (e.g., AWS S3, Google Cloud Storage, Azure Blob Storage) or a specialized artifact registry.
3.  **Runtime**:
    - Download the image from storage for each test run.
    - Use ephemeral runners that discard the state after testing.
    - Inject secrets (API keys, SSH keys) strictly at runtime using cloud-init or environment variables, **never** bake them into the image.

## Security Notes

- **Firewall**: The image comes with a strict "deny-by-default" firewall. Only SSH (port 22), ICMP, and established connections are allowed inbound.
- **Root Access**: Root SSH login is disabled. Password authentication is disabled by default; users must provision an SSH public key (e.g., via `fedora` user's `authorized_keys` or instance metadata) to access the machine. Ensure your key is installed before booting. Use the `fedora` user with `sudo`.
