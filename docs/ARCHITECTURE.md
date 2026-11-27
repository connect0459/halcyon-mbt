# Architecture

## Package graph

```text
connect0459/halcyon/internal/inflate   no deps         [internal]  DEFLATE / zlib decompression
connect0459/halcyon/image              no deps                     PixelBuffer, ImageFormat, ImageKey, geometry value objects
        │
        ├── connect0459/halcyon/decode          deps: @image            ImageDecoder trait, DecodeError, format detection
        │         │
        │         ├── connect0459/halcyon/decode/png   deps: @decode, @inflate
        │         └── connect0459/halcyon/decode/jpeg  deps: @decode
        │
        ├── connect0459/halcyon/process         deps: @image            ImageProcessor trait, Resize / Crop / Compose
        ├── connect0459/halcyon/cache           deps: @image            MemoryCache (LRU, cost, TTL), injected Clock
        └── connect0459/halcyon/source          deps: @image            Fetcher / DiskStore traits (abstract only)

connect0459/halcyon/pipeline           deps: all of the above          Keyer → memory → Fetcher → disk → decode → process
connect0459/halcyon                    facade                          public re-exports
```

`internal/inflate` is hidden from consumers through MoonBit's `internal` package convention.

## Design lineage

| Concern | Borrowed from | Form here |
| :--- | :--- | :--- |
| Pipeline decomposition | Coil | Each stage declines work it does not own and delegates to the next |
| Two-layer cache | Nuke | Memory holds processed images; disk holds raw data with LRU eviction |
| Cache identity | Nuke | A processor exposes an `identifier` that is part of the cache key |
| Decoder abstraction | Rust `image` | `ImageDecoder` trait per format, opt-in resource limits |

## Layer boundaries

- `source` defines `Fetcher` and `DiskStore` as abstract types only. HTTP and file system implementations are separate packages per target, so the core stays pure and runs on all four backends.
- `pipeline` depends on abstractions, never on a concrete decoder or store.
- Time is injected through a `Clock` abstraction so cache expiry is testable without sleeping.
