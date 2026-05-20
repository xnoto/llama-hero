FROM docker.io/python:3.12-slim

ARG FORGE_VERSION=0.6.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "forge-guardrails==${FORGE_VERSION}"

EXPOSE 8081

CMD ["python", "-m", "forge.proxy", "--help"]
