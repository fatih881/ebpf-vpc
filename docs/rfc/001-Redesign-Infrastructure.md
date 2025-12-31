# RFC: Redesign Infrastructure for CI/CD Workflows
Owner: Fatih K.
Status: proposed
Foreword
In a previous attempt, images configured by Packer had hardcoded credentials (In DockerFiles which was deployed) and unnecessary SSH key implementations (ansible.pub).
The goal is to meet the need for an immutable, secure, and observable infrastructure for CI/CD workflows.
This redesign is the successor of test infrastructure design attempt on ebpf-fw repository. (GitHub: [ebpf-fw repository](https://github.com/fatih881/ebpf-fw))
Motivation
The motivation behind this redesign is;
- Hardcoded Credentials in golden images
- Unable to deploy images multiple because baked images are completely same.
Requirements
- Baking images via Ansible Playbooks & HashiCorp Packer with only immutable sections.
- The infrastructure must be Horizontally scalable by default.
- Golden image must not include any credentials before cloud-init.
- GitHub Action Listeners must be run on bare metal since we need to use NIC directly for integration tests (also, tests must leave a clean enviorement even in failing), control plane must be using a Kubernetes distribution which will be suit our needs.
Kubernetes distribution selection is open for discussing.
Implementation
- Configuration : Ansible is selected for maintain,scalability and flexibility on both with Packer & suiting other configuration needs on other needs in workflows.
- Golden Image : HashiCorp Packer is selected for immutable golden images and prevent configuration drift.
- GitHub Actions Listener : Since we need to work on features of NIC's, GitHub Actions cannot run integration tests on a virtualized enviorement. Other test types can be run on containers for keeping the enviorement clean.
- Secret Management : Ansible Vault is used at baking process,and HashiCorp vault or GitHub Secrets can be used for enjecting secrets via cloud-init at deploy.
- Horizontally Scalability : Nodes must connect to a control plane via Cloudflare tunnels.Control plane will host Grafana for the metrics fetched from that workers. Also,collecting & serving dmesg logs via Loki is a must.
- Identifying nodes : Nodes must register themselves with useful identifiers on both GitHub Labels,labeling logs sent by Loki and for control plane. NIC model,Driver,kernel version and PCIe Link Speed is selected for this repository's needs.
This process must be a oneshot Systemd service which will run between cloud-init and GitHub Actions registration. 
Baked images must available to use cloud-init when deploying.  
Image Generated Via Gemini:  
![001-RFC-Diagram.png](001-RFC-Diagram.png)












