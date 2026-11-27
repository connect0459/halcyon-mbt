# Security Policy

## Supported Versions

Only the latest release on the `main` branch is actively maintained. Older versions do not receive security fixes.

| Version  | Supported |
| :------- | :-------- |
| latest   | ✓         |
| < latest | ✗         |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Use GitHub's [private vulnerability reporting][private-report] feature to disclose issues confidentially. You will receive an acknowledgment within **5 business days** and a resolution timeline once the report has been triaged.

[private-report]: https://github.com/connect0459/halcyon-mbt/security/advisories/new

## Scope

The following vulnerability classes are in scope for this project:

- **Decoder crashes** — any input (including truncated, malformed, or adversarially crafted PNG and JPEG data) that causes a panic, out-of-bounds access, or unhandled runtime error in a decoder instead of a typed decode error.
- **Resource exhaustion** — inputs that make a decoder allocate or loop disproportionately to the input size (for example decompression bombs or inflated image dimensions) and bypass the configured limits.
- **Cache confusion** — cache keys or processor identifiers that collide so that one request is served another request's image, or that let untrusted input poison a shared cache entry.
- **Incorrect decoding results** — silent data corruption or wrong pixels that could mislead an application in a security-relevant way.

The following are **out of scope**:

- Issues in third-party dependencies (report those upstream).
- Theoretical issues without a reproducible proof-of-concept.
- Differences in decoded pixels that fall within the documented tolerance against the reference decoder.

## Disclosure Policy

Once a fix is ready and released, a GitHub Security Advisory will be published with full details. The typical timeline from report to public disclosure is **30 days**, though this may be extended by mutual agreement when a fix requires significant changes.
