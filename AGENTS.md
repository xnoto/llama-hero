# AGENTS.md

Operational guidance for agents changing the `llama-hero` deployment repository.

## Repository role

This repository owns the Podman Quadlet, model manifest, Forge proxy container, and deployment scripts for the `hero` inference host. It is application/deployment source, not the installed state on `hero`.

Treat these files as the current deployment authority:

- `models.json` for model size, architecture, context, and GPU-layer assumptions
- `quadlet/llama-server.container` for the active image, model, context, ports, and runtime flags
- `quadlet/forge-proxy.container` and `container/` for the optional Forge proxy

Keep README tables synchronized with those files. Run the VRAM budget validator whenever model, quantization, context, layer offload, or GPU assumptions change.

## Safety boundaries

Safe local validation:

```bash
make lint
python3 scripts/check_vram_budget.py models.json
pre-commit run --all-files
```

The pre-commit ShellCheck hook uses a container and therefore needs a working
Docker daemon. On a host without Docker, run `SKIP=shellcheck pre-commit run
--all-files` plus the system `shellcheck --severity=warning scripts/*.sh`; CI remains the
authoritative container-backed check.

The following targets connect to `hero`, copy files, build images, or change user services and require explicit confirmation:

- `make install`
- `make install-forge-proxy`
- `make deploy-test`
- `make cutover`
- `make clean-test`
- direct `ssh`, `scp`, or remote `systemctl` commands

Do not infer deployed state solely from local files. Inspect the host only when authorized, and do not start, stop, restart, or replace a service without confirmation.

## Compatibility invariants

- Preserve RHEL 9.2, rootless Podman 4.4.1, systemd 252, ROCm, and dual Radeon VII constraints unless the target host changes.
- Podman 4.4 Quadlet supports a limited directive set. Keep unsupported options in `PodmanArgs=` as documented in the container file.
- Preserve the stable pinned llama.cpp image until a newer image is separately qualified.
- Forge coalesces system messages for the current Qwen template. Do not enable native `--jinja` tool calling or remove the conversion patch without an integration test.
- Forge 0.9 separates proxy liveness (`/forge/health`) from forwarded backend readiness (`/health`); use the former for the container health command and the latter when deployment scripts must wait for llama-server.
- Never commit model files, generated service state, credentials, or host-specific runtime data.

## Contribution workflow

Work on a feature branch and use Conventional Commits. Validate locally, then let CI perform Quadlet, container image, ShellCheck, dead-code, schema, and VRAM checks. Recheck the working tree after validation. Do not deploy as part of validation.
