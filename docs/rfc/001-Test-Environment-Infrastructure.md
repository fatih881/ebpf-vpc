# RFC: Design of Infrastructure for Test & Benchmark Environment 
Owner: Fatih Karaoğlu

### Foreword

In a previous attempt, images configured by Packer had hardcoded credentials (In DockerFiles which was deployed) and unnecessary SSH key implementations (ansible.pub).  
The goal is to meet the need for an immutable, secure, and observable infrastructure for tests and benchmarks on both go and custom driver patches.  
This design is the successor of test infrastructure design attempt on ebpf-fw repository. (GitHub: [ebpf-fw repository](https://github.com/fatih881/ebpf-fw))

### Motivation

The motivations behind this redesign is;
  - Previous attempt revealing secrets at DockerFile as a text,
  - Tests and benchmarks on patched drivers require more dependencies and have optimization opportunities like ccache,
  - 
### Requirements

- Configuration : Ansible is selected for reproducibility of configurations.
- Packer : Packer is used for efficiency,immutability and reproducibility.(e.g, with Ansible,we need to download related files in every deploy,but with Packer,only 1 time is enough.)
- Hardware Check : When configuring,a play will make sure kernel suits our needs on XDP/eBPF related tests.This check only contains;
    - Creating a Dummy iface and loading XDP.With this test,we will make sure necessary features are enabled.
    - Since the result of this integration test will cover everything we need end 2 end,(e.g,checking related kernel options are enabled),no necessary implementations found necessary on eBPF.
- ccache : To prevent resource waste,ccache will allow us to only compile edited files,and serve others from cache to reduce CPU/ram usage significantly when compiling.
- Secret Management : Since secret management is bullet points of technical debts of previous attempt,related PR to this RFC is going to use cloud-init on secret management. See  [How security risks are prevented?](#to-provide-security--isolation-)
- Documentation about usage & example cloud-init files must be provided.
####   To Provide Security & Isolation ;
  - Cloud-init must inject secrets as Environment vars and no secret shall be written to persistent files,
  - r/w access to Config files(e.g,CloudFlared) must be restricted,
  - Cloud-init must remove every evidence of secrets(e.g,caches,logs,histories),
  - SSH Root login must be disabled,Root execution privileges are restricted exclusively to the local CI runner via sudoers, with no external access permitted,
  - Generated image must run via QEMU for isolation.  
  - Cloud-init must close all firewalls but loopback and CloudFlared & GitHub Actions Listener after run.Dependencies(e.g,DNS queries) must be allowed.
    - This service must have `Before=network-pre.target` order. 