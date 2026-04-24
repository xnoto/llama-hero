# llama-hero

Podman Quadlet configuration for a self-hosted [llama.cpp](https://github.com/ggml-org/llama.cpp) inference server on **hero** (`hero.makeitwork.cloud`).

## Hardware

| Component | Spec |
|---|---|
| GPUs | 2x AMD Radeon VII (Vega 20 / gfx906), 16 GiB VRAM each |
| System RAM | 128 GiB DDR4 (available for partial GPU offload) |
| CPU | 32 cores |
| OS | RHEL 9.2, Podman 4.4.1, systemd 252 |
| Container runtime | Rootless Podman with ROCm 6.3.3 |

## VRAM budget

| Model | Quant | Context | Est. VRAM | Headroom |
|---|---|---|---|---|
| Qwen3.6-35B-A3B | Q4_K_M | 128K | ~26 GiB | ~6 GiB (19%) |
| Qwen2.5-Coder-32B | Q5_K_M | 32K | ~31 GiB | ~1 GiB (3%) |
| Qwen2.5-Coder-32B | Q4_K_M | 32K | ~28 GiB | ~4 GiB (13%) |
| Qwen2.5-Coder-32B | Q4_0 | 32K | ~27 GiB | ~5 GiB (16%) |

Total GPU VRAM: 2x 16 GiB = 32 GiB. All layers offloaded, split evenly (`--tensor-split 1,1`).

Larger models can use partial GPU offload (`-ngl <N>` instead of `-ngl all`) to spill remaining layers to the 128 GiB system RAM. Set `n_gpu_layers` per model in `models.json`; the VRAM budget script calculates the split.

## Deployment

### Prerequisites

- SSH access to hero as `user`
- `loginctl enable-linger user` on hero (survives logout)

### Install

```sh
make install        # copy Quadlet files to hero, daemon-reload
ssh user@hero systemctl --user start llama-server.service
```

The Quadlet-generated service starts automatically on boot (via `WantedBy=default.target` + linger). No `systemctl enable` needed — the `.container` file's presence is the enable.

### Deploy with health check

```sh
make deploy-test    # stops existing service, deploys, starts, polls /health
```

### Rollback

If the health check fails, `deploy-test.sh` automatically attempts to restart the previous `container-llama-server.service`. The original unit file is archived as `container-llama-server.service.pre-quadlet` in `~/.config/systemd/user/`.

## File layout

```
quadlet/
  llama-server.container   Podman Quadlet unit (deployed to ~/.config/containers/systemd/)
  llama-server.env         Optional environment overrides (ROCm tuning)
models.json                Model manifest (name, file, quant, context, architecture params)
schemas/
  models.schema.json       JSON Schema for models.json
scripts/
  check_vram_budget.py     VRAM budget validator (supports partial GPU offload)
  deploy-test.sh           Deploy Quadlet, start service, poll health
  cutover.sh               Archive old podman-generate-systemd unit
```

## CI

Pull requests and pushes to `main` run:

- **Quadlet validation** (`quadlet -dryrun` + `systemd-analyze verify`)
- **Container image check** (`skopeo inspect` confirms the image tag exists)
- **ShellCheck** on scripts
- **Dead code check** (`vulture` on Python scripts)
- **JSON schema validation** on `models.json`
- **VRAM budget check** (estimated usage vs. 32 GiB budget)

[Renovate](https://docs.renovatebot.com/) watches for new container image tags via its native Quadlet manager.

## Podman 4.4 compatibility

Hero runs Podman 4.4.1 (RHEL 9.2). The Quadlet generator in 4.4.x supports a very limited set of native directives (`Image=`, `Exec=`, `PodmanArgs=`, and a few others). Most container options — including `AddDevice=`, `GroupAdd=`, `SecurityLabelDisable=`, `AutoUpdate=`, and all `Health*=` directives — are passed as raw flags via `PodmanArgs=` instead. See comments in the `.container` file.

## License

MIT
