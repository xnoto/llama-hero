# Changelog

## [0.3.0](https://github.com/xnoto/llama-hero/compare/v0.2.0...v0.3.0) (2026-08-14)


### Features

* add Forge proxy deployment ([dbf9ea9](https://github.com/xnoto/llama-hero/commit/dbf9ea9d4a8b65577a3d9b4d43bf443ebc4c945c))
* increase context to 224K, set single parallel slot ([71a4a4a](https://github.com/xnoto/llama-hero/commit/71a4a4a2c423d05e38443aa2a0c1da2b67f848be))
* increase context window from 128K to 192K ([68ef801](https://github.com/xnoto/llama-hero/commit/68ef8013952e6d7ff9fa5f82e253ddbee1d051cc))


### Bug Fixes

* align AWS MCP names ([510292c](https://github.com/xnoto/llama-hero/commit/510292c4bc76ba975c67eacb05428188046df3ba))
* disable incompatible jinja template mode ([92f5c0e](https://github.com/xnoto/llama-hero/commit/92f5c0ee0328a1491d88f4a69c9070cb789448dd))
* disable unbounded reasoning budget ([6f17ed8](https://github.com/xnoto/llama-hero/commit/6f17ed8e9bb217419a7f7e232386ce69dbe16ee3))
* enable llama-server jinja tool formatting ([8f86126](https://github.com/xnoto/llama-hero/commit/8f86126c04ca739a2d11ef3544513ede1442da74))
* hide Qwen reasoning in Forge tool calls ([25f7f09](https://github.com/xnoto/llama-hero/commit/25f7f09428b15260b1a4911a867ec1d1de05fb55))
* normalize system messages in Forge proxy ([641a0d6](https://github.com/xnoto/llama-hero/commit/641a0d635390b3379c75c7f775c8db71c574690c))
* roll back unstable llama.cpp image ([28ba2cc](https://github.com/xnoto/llama-hero/commit/28ba2cc8c03df9d9d127485f06cbae8a15d7a640))
* route project MCPs through shared gateway ([#3](https://github.com/xnoto/llama-hero/issues/3)) ([abc029d](https://github.com/xnoto/llama-hero/commit/abc029d067ed5345278c6ecdb69a4faf7e10e992))
* wait for chat readiness during deploy ([173eca5](https://github.com/xnoto/llama-hero/commit/173eca554bfa10af7b26d860f9168ee0b32c8376))

## [0.2.0](https://github.com/xnoto/llama-hero/compare/v0.1.0...v0.2.0) (2026-04-24)


### Features

* initial repo — Podman Quadlet for llama.cpp on hero ([4b7ec3f](https://github.com/xnoto/llama-hero/commit/4b7ec3fcbfdf85e3492a35723b54f915ffeece22))


### Bug Fixes

* resolve ShellCheck warnings in deploy scripts ([b922e9b](https://github.com/xnoto/llama-hero/commit/b922e9bc573f1fcefa90f5b6c700e8a2faac70d2))
* set ShellCheck severity to warning in CI ([b07de4c](https://github.com/xnoto/llama-hero/commit/b07de4cccf3d4dfbff25eb8155be3322c171ecdb))

## Changelog
