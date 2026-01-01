### Why is the mlx5 driver source code included here?
This directory contains a modified version of the NVIDIA/Mellanox `mlx5_core` driver to be used instead of eBPF in specific conditions.
While eBPF is the primary tool for observability and networking,specific needs may met via custom Asynchronous Hardware Signals.
Since eBPF is more efficient & reliable in %99 scenarios,these patches will still be implemented because they may be helpful in optimizing CPU instructions or making sense of benchmarks more efficiently.
