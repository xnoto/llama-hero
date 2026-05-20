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

### Forge guardrails proxy

[Forge](https://github.com/antoinezambelli/forge) can run as an additive OpenAI-compatible proxy in front of the existing `llama-server`:

```text
client -> hero:8081 -> forge-proxy -> hero:8080 -> llama-server -> GGUF model
```

The proxy adds tool-calling guardrails, retry nudges, response rescue, context budgeting, and request serialization without changing the deployed model. This repository intentionally keeps the current `llama-server` model and launch flags unchanged; Forge is deployed as a separate service.

Install/start the proxy:

```sh
make install-forge-proxy
```

That target builds `localhost/forge-proxy:0.6.0` on `hero`, installs `quadlet/forge-proxy.container`, restarts `forge-proxy.service`, and polls `http://localhost:8081/health`.

Clients should use:

```text
http://hero.makeitwork.cloud:8081/v1
```

instead of direct access to llama-server on `8080`.

Notes:

- Forge requires Python 3.12+, so it is containerized rather than installed on the RHEL 9.2 host Python.
- The proxy publishes host port `8081` and reaches the existing llama-server through Podman's `host.containers.internal:8080` alias.
- Native llama.cpp tool calling via `llama-server --jinja` is intentionally disabled for this Qwen3.6/opencode path. The model template rejects some opencode conversation shapes with `System message must be at the beginning`; Forge therefore uses its fallback guardrails instead.
- The Forge proxy image patches Forge's OpenAI-message conversion to coalesce all `system` messages into one leading system prompt before forwarding to llama-server. This protects Qwen's GGUF template from opencode's per-turn system messages.
- The newer `full-b8763` image restarted under the current Qwen3.6 + 224K context deployment. The server is pinned to the prior stable `full-b8667` image until the newer build can be qualified separately.

### Rollback

If the health check fails, `deploy-test.sh` automatically attempts to restart the previous `container-llama-server.service`. The original unit file is archived as `container-llama-server.service.pre-quadlet` in `~/.config/systemd/user/`.

## File layout

```
quadlet/
  llama-server.container   Podman Quadlet unit (deployed to ~/.config/containers/systemd/)
  forge-proxy.container    Optional Forge proxy Quadlet (deployed to ~/.config/containers/systemd/)
  llama-server.env         Optional environment overrides (ROCm tuning)
container/
  forge-proxy.Containerfile  Python 3.12 image with forge-guardrails installed
models.json                Model manifest (name, file, quant, context, architecture params)
schemas/
  models.schema.json       JSON Schema for models.json
scripts/
  check_vram_budget.py     VRAM budget validator (supports partial GPU offload)
  deploy-test.sh           Deploy Quadlet, start service, poll health
  install-forge-proxy.sh   Build/install/start the Forge proxy service
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
