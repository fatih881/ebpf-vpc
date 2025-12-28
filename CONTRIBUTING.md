# Contributing to project

As a project focused on low-level infrastructure, hardware offloading, and kernel bypass technologies, we adhere to the rigor and standards of the **Linux Kernel** community.

## 1. Development Philosophy
*   **Performance:** Every instruction matters.
*   **Correctness:** race-free concurrency,portability and determinism are a must.
*   **Hardware:** Changes often target specific hardware (e.g., ConnectX-5+,). Verify will be provided at CI/CD.

## 2. Commit Message Guidelines
This repository strictly follow the **Linux Kernel** commit message conventions.
Reference: [Linux Kernel Submitting Patches](https://www.kernel.org/doc/html/latest/process/submitting-patches.html)

### Structure
```text
subsystem/scope: concise summary (under 50 chars)

Detailed explanation of the problem (WHY).
Detailed explanation of the solution (HOW).
Hardware verification details (if applicable).

Fixes: 1234567890ab ("subsystem: original commit title")
Signed-off-by: Your Name <your.email@example.com>
```

### Examples
**Good:**
```text
dataplane/xdp: implement LSU-Hashmap for Fast Path 

The previous insertion logic is checking every package in one flow,with this patch CPU usage is lowered by %x 
in a 200G nginx benchmark with a single flow.
LSU-Hashmap must be edited when tenant changes a firewall rule which is presented in lSU-Hashmap.

Signed-off-by: Name Surname <name@domain.com>
```

**Bad:**
*   `fix bug` (Too vague)
*   `feat: add new feature` (Not enough info)

## 3. Developer Certificate of Origin (DCO)
All contributions must be signed off. By adding `Signed-off-by` to your commit, you certify that you have the right to submit this code under the project's license.

Use `git commit -s` to automatically add this line.

## 4. Coding Style
*   **Go:** Follow standard Go idioms. Run `gofmt -s` and `golangci-lint` before submitting. Please see [ Effective Go](https://go.dev/doc/effective_go).
*   **C / eBPF:** Follow the [Linux Kernel Coding Style](https://www.kernel.org/doc/html/latest/process/coding-style.html).
    *   Use `scripts/checkpatch.pl` (if available) or standard kernel style checkers.
    *   Maximize readability and understandability on workflows,playbooks,source code etc.

## 5. Patch Submission
*   **Pull Requests:** GitHub Pull Requests are used for collabration.
*   **One logical change per PR:** Do not bundle unrelated refactors with features.

## 6. Resources
*   [Linux Kernel: Submitting Patches](https://www.kernel.org/doc/html/latest/process/submitting-patches.html)
*   [Linux Kernel: Networking (netdev) FAQ](https://www.kernel.org/doc/html/latest/process/maintainer-netdev.html)
