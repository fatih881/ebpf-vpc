# Ansible Playbooks for Test Environment of the repository 

This directory contains Ansible playbooks to deploy a secure and observable self-hosted test environment to be used by the repository's tests.

## Services Deployed

Grafana, Loki, and Prometheus are deployed for observability, and Cloudflared is used for accessing these services securely. A GitHub runner is also configured within the playbooks. All services are deployed with Docker Compose because they are the essentials. Tests may be distributed using a Kubernetes distribution.
*   **Observability stack is a must for diagnose on the metrics,unstable behaviors and further(for example,CPU IRQ times)**
## How to Use

1.  **Configure `inventory/hosts.yml`:**
    *   Edit `inventory/hosts.yml` to specify your target server(s):
        ```yaml
        all:
          hosts:
          children:
            test:
              hosts:
                my-server-1:
                  ansible_host: 192.168.1.100
        ```
2.  **Configure `inventory/group_vars/all.yml`:**
    *   Ensure the `ansible_user` and paths to your SSH keys (`ssh_key_ansible`, `ssh_key_root`) are correct.
        ```yaml
        ---
        ansible_user: ansible
        ssh_key_ansible: ~/.ssh/ansible_id_rsa # Path to ansible user's private key
        ssh_key_root: ~/.ssh/root_id_rsa     # Path to root's private key for initial bootstrap.
        ```
3.  **Prepare `secrets.yml`:**
    *   Create or edit `secrets.yml` and encrypt it using Ansible Vault.
    *   Ensure it contains the necessary sensitive variables. **Fill in the actual values:**
        ```yaml
        # Example content for secrets.yml (encryption is mandatory for this file)
        github_repo_url: "https://github.com/your-org/your-repo"
        github_pat: "ghp_YOUR_GITHUB_PERSONAL_ACCESS_TOKEN"
        cloudflare_api_token: "YOUR_CLOUDFLARE_API_TOKEN"
        cloudflare_account_id: "YOUR_CLOUDFLARE_ACCOUNT_ID"
        cloudflare_tunnel_token: "YOUR_EXISTING_CLOUDFLARE_TUNNEL_TOKEN"
        cloudflare_tunnel_name: "your-tunnel-name"
        grafana_admin_user: "example"
        grafana_admin_password: "YOUR_GRAFANA_ADMIN_PASSWORD"
        slack_api_url: "https://hooks.slack.com/services/TXXXXX/BXXXXX/XXXXXX"
        ```
    *   **Encrypt `secrets.yml`:** `ansible-vault encrypt secrets.yml`

> Secrets will work while it's not encrypted, but it's not recommended.

## Important Points

*   **Bootstrap Playbook Execution (Root Access):** The `bootstrap.yaml` playbook initially attempts to connect as `root` to perform setup tasks and then disables `root` login. Consequently, if the playbook is run multiple times, subsequent attempts to connect as `root` in this play are expected to fail. This is intentional and will not halt the overall playbook execution, as subsequent plays connect as the `ansible` user. This logic is open for community contributions for refinement.
*   **Recommended usage is a golden-image approach** (see https://www.redhat.com/en/topics/linux/what-is-a-golden-image).
*   **Cloudflare Tunnel:** Cloudflare Tunneling is included for enhanced security. It requires a registered domain, a Cloudflare account, and some initial configuration. Its use is optional and can be removed or adapted to your specific networking needs.

### Roadmap & TODO

 - [] Adding a playbook for running end2end tests with virtme-ng
 - [] Distributing end-to-end test logic, as it will run on several kernel versions
