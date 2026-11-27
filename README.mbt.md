# halcyon-mbt

[![CI](https://github.com/connect0459/halcyon-mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/connect0459/halcyon-mbt/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/connect0459/halcyon-mbt/blob/main/LICENSE)

An image loading, decoding, processing, and caching library for [MoonBit](https://moonbitlang.com).

> **Status: pre-alpha.** No public API exists yet. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the planned design and [docs/todo.md](docs/todo.md) for progress.

## Goals

- Pure MoonBit PNG and JPEG decoding that runs on all four backends (`js`, `wasm`, `wasm-gc`, `native`)
- Composable image processors with identity-based cache keys
- A two-layer cache (memory and disk) behind abstract types
- A loading pipeline that separates fetching, caching, decoding, and processing
