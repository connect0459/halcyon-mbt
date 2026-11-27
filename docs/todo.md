# todo - halcyon

Current state: **phase 3 complete.**

---

## Decisions

- **Scope**: image loading pipeline in the spirit of Kingfisher, built from small packages (see `ARCHITECTURE.md`). Display is out of scope.
- **Targets**: all four backends (`js`, `wasm`, `wasm-gc`, `native`) from the start.
- **Decoders**: PNG and JPEG (baseline, then progressive) are implemented in this repository, with no codec dependency.
- **Test oracle**: expectations come from fixed fixtures under `testdata/`, produced by a reference decoder (libpng / libjpeg-turbo) by scripts under `tools/`. Each fixture records its provenance. The test suite never depends on another MoonBit codec at run time.
- **JPEG comparison**: the reference configuration is libjpeg-turbo with the `islow` DCT, fancy upsampling, and no block smoothing. The decoder reproduces that arithmetic, so the allowed maximum per-channel difference is zero.
- **Coverage goal**: every reachable line. Provably unreachable lines are documented.
- **Naming**: module `connect0459/halcyon`, repository `halcyon-mbt`.

## Open questions

- [ ] **Asynchrony**: which mechanism works on all four backends for `Fetcher` and `DiskStore`? `moonbitlang/async` support per target is unverified. Phases 1-3 are synchronous and unaffected. Decide before phase 4.

---

## Phases

Each phase follows Red → Green → Refactor.

- [x] **Phase 1 — Pure logic**: `image`, `process`, `cache`
- [x] **Phase 2 — PNG**: `internal/inflate`, `decode`, `decode/png`, with PngSuite-based fixtures
- [x] **Phase 3 — JPEG**: baseline, then progressive
- [ ] **Phase 4 — Pipeline and I/O**: `source`, `pipeline`, per-target `Fetcher` / `DiskStore` implementations

---

## Infrastructure

- [x] Community standard docs, `AGENTS.md` / `CLAUDE.md`, pre-commit, CI, publish workflows replicated from `urllib-mbt`
- [ ] Run `apm install` to generate `apm.lock.yaml` and deploy agent skills
- [ ] Create the GitHub repository and configure branch protection on the `gate` job
- [ ] Configure the `MOONCAKES_CREDENTIALS` secret before the first release
