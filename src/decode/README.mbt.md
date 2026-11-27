# connect0459/halcyon/decode

Format-independent decoding vocabulary.

| Item | Purpose |
| :--- | :--- |
| `ImageDecoder` | Trait with `format()` and `decode(bytes)`; format packages provide implementations. |
| `detect_format(bytes)` | Recognises PNG and JPEG from the leading bytes. |
| `DecodeError` | `UnknownFormat`, `Truncated`, `Malformed`, `Unsupported`, `LimitExceeded`. |
| `DecodeLimits` | Opt-in resource limit. The default admits up to 100,000,000 pixels and is checked before any pixel memory is allocated. |
