FROM docker.io/python:3.12-slim

ARG FORGE_VERSION=0.9.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "forge-guardrails==${FORGE_VERSION}"

COPY patch-forge-qwen-system.py /tmp/patch-forge-qwen-system.py
RUN python /tmp/patch-forge-qwen-system.py \
    && rm /tmp/patch-forge-qwen-system.py

EXPOSE 8081

CMD ["python", "-m", "forge.proxy", "--help"]
