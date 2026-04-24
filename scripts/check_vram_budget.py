#!/usr/bin/env python3
"""
VRAM budget validator for llama.cpp model serving.

Estimates total memory usage for each model in models.json and checks
against available GPU VRAM and system RAM.

VRAM estimation:
  model_weights ~= file_size_on_disk (GGUF is mmap'd, roughly 1:1)
  kv_cache = 2 * n_kv_heads * head_dim * n_layers * context * bytes_per_element
  overhead ~= 0.75 GiB (driver, compute buffers)

Partial offload (n_gpu_layers != -1):
  Only n_gpu_layers worth of weights go to VRAM; the rest spill to system RAM.
  KV cache stays on whatever device holds each layer.
"""

import json
import sys

GIB = 1024 ** 3

DEFAULT_GPU_COUNT = 2
DEFAULT_GPU_VRAM = 16 * GIB
DEFAULT_SYSTEM_RAM = 128 * GIB

OVERHEAD_BYTES = int(0.75 * GIB)
KV_BYTES_PER_ELEMENT = 2  # FP16


def estimate_kv_cache(model: dict) -> int | None:
    """Estimate KV cache VRAM in bytes. Returns None if arch info missing."""
    n_kv_heads = model.get("n_kv_heads") or model.get("n_heads")
    head_dim = model.get("head_dim")
    n_layers = model.get("n_layers")
    ctx = model.get("context_window")

    if not all([n_kv_heads, head_dim, n_layers, ctx]):
        return None

    return 2 * n_kv_heads * head_dim * n_layers * ctx * KV_BYTES_PER_ELEMENT


def estimate_vram(model: dict) -> tuple[int, int, str]:
    """Return (vram_bytes, ram_bytes, breakdown_string)."""
    weights = model["size_bytes"]
    n_layers = model.get("n_layers", 0)
    n_gpu_layers = model.get("n_gpu_layers", -1)
    kv = estimate_kv_cache(model)

    if kv is None:
        kv = int(weights * 0.25)
        kv_label = f"kv_cache={kv / GIB:.2f}G(est)"
    else:
        kv_label = f"kv_cache={kv / GIB:.2f}G"

    # Full offload
    if n_gpu_layers == -1 or (n_layers > 0 and n_gpu_layers >= n_layers):
        vram = weights + kv + OVERHEAD_BYTES
        ram = 0
        parts = f"weights={weights / GIB:.2f}G + {kv_label} + overhead=0.75G [all GPU]"
    else:
        # Partial offload: split weights and KV cache by layer ratio
        gpu_frac = n_gpu_layers / n_layers if n_layers > 0 else 0
        gpu_weights = int(weights * gpu_frac)
        ram_weights = weights - gpu_weights
        gpu_kv = int(kv * gpu_frac)
        ram_kv = kv - gpu_kv
        vram = gpu_weights + gpu_kv + OVERHEAD_BYTES
        ram = ram_weights + ram_kv
        parts = (
            f"GPU: {gpu_weights / GIB:.2f}G weights + {gpu_kv / GIB:.2f}G kv "
            f"({n_gpu_layers}/{n_layers} layers) | "
            f"RAM: {ram_weights / GIB:.2f}G weights + {ram_kv / GIB:.2f}G kv"
        )

    return vram, ram, parts


def main():
    if len(sys.argv) < 2:
        print("Usage: check_vram_budget.py <models.json>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        manifest = json.load(f)

    gpu_cfg = manifest.get("gpu", {})
    gpu_count = gpu_cfg.get("count", DEFAULT_GPU_COUNT)
    gpu_vram = gpu_cfg.get("vram_bytes", DEFAULT_GPU_VRAM)
    total_vram = gpu_count * gpu_vram
    total_ram = manifest.get("system_ram_bytes", DEFAULT_SYSTEM_RAM)

    print(f"GPU budget:    {gpu_count}x {gpu_vram / GIB:.0f} GiB = {total_vram / GIB:.0f} GiB VRAM")
    print(f"System RAM:    {total_ram / GIB:.0f} GiB")
    print()

    failures = []

    for model in manifest["models"]:
        name = model["name"]
        vram, ram, breakdown = estimate_vram(model)
        vram_pct = (vram / total_vram) * 100

        if vram > total_vram:
            status = "VRAM OVER"
            failures.append(name)
        elif ram > total_ram:
            status = "RAM OVER"
            failures.append(name)
        elif vram_pct > 90:
            status = "TIGHT"
        else:
            status = "OK"

        print(f"  {name}:")
        print(f"    VRAM: {vram / GIB:.2f} GiB ({vram_pct:.0f}%) | RAM: {ram / GIB:.2f} GiB | {status}")
        print(f"    [{breakdown}]")
        print()

    if failures:
        print(f"FAIL: {len(failures)} model(s) exceed budget: {', '.join(failures)}", file=sys.stderr)
        sys.exit(1)

    print("All models within budget.")


if __name__ == "__main__":
    main()
