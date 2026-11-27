#!/usr/bin/env python3
"""Generate JPEG decoder test fixtures.

Synthetic source images are compressed with cjpeg into testdata/jpeg, then
decoded by the libjpeg reference program built from tools/jpeg_reference.c.

Usage: tools/gen_jpeg_fixtures.py PATH_TO_JPEG_REFERENCE_BINARY [CJPEG]
"""
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "testdata" / "jpeg"
OUTPUT = ROOT / "src" / "decode" / "jpeg" / "jpeg_fixtures_test.mbt"


def source_image(width: int, height: int, channels: int, seed: int) -> bytes:
    state = seed * 2654435761 % (1 << 32) or 1
    data = bytearray()
    for y in range(height):
        for x in range(width):
            for c in range(channels):
                state = (state * 1664525 + 1013904223) % (1 << 32)
                noise = (state >> 24) % 48
                gradient = (x * 255 // max(width - 1, 1) + c * 85) % 256
                band = 200 if ((x // 5 + y // 4 + c) % 3 == 0) else 20
                value = (gradient * 2 + band + noise * 2) // 4
                data.append(min(255, value))
    return bytes(data)


def pnm(width: int, height: int, channels: int, seed: int) -> bytes:
    magic = b"P6" if channels == 3 else b"P5"
    header = magic + b" %d %d 255\n" % (width, height)
    return header + source_image(width, height, channels, seed)


SIZES = [(1, 1), (17, 13), (33, 31)]
SAMPLINGS = {"444": "1x1", "422": "2x1", "440": "1x2", "420": "2x2"}

CASES = []
for label, factor in SAMPLINGS.items():
    for w, h in SIZES:
        CASES.append((f"base_{label}_{w}x{h}", w, h, 3, ["-sample", factor]))
        CASES.append((f"prog_{label}_{w}x{h}", w, h, 3, ["-sample", factor, "-progressive"]))
    CASES.append((f"base_{label}_64x48_q95", 64, 48, 3, ["-sample", factor, "-quality", "95"]))
for w, h in SIZES:
    CASES.append((f"base_gray_{w}x{h}", w, h, 1, ["-grayscale"]))
    CASES.append((f"prog_gray_{w}x{h}", w, h, 1, ["-grayscale", "-progressive"]))
CASES += [
    ("base_420_64x48_q10", 64, 48, 3, ["-quality", "10"]),
    ("base_420_64x48_q100", 64, 48, 3, ["-quality", "100"]),
    ("base_420_optimized", 64, 48, 3, ["-optimize"]),
    ("base_420_restart_rows", 64, 48, 3, ["-restart", "1"]),
    ("base_420_restart_blocks", 64, 48, 3, ["-restart", "3B"]),
    ("base_444_restart_blocks", 33, 31, 3, ["-sample", "1x1", "-restart", "5B"]),
    ("base_rgb_17x13", 17, 13, 3, ["-rgb"]),
    ("base_411_33x31", 33, 31, 3, ["-sample", "4x1,1x1,1x1"]),
    ("base_gray_restart", 33, 31, 1, ["-grayscale", "-restart", "2B"]),
    ("prog_420_restart", 64, 48, 3, ["-progressive", "-restart", "2B"]),
    ("prog_420_64x48_q100", 64, 48, 3, ["-progressive", "-quality", "100"]),
    ("prog_rgb_17x13", 17, 13, 3, ["-rgb", "-progressive"]),
]


def literal(data: bytes) -> str:
    return 'b"' + "".join("\\x%02x" % byte for byte in data) + '"'


def main() -> None:
    reference = sys.argv[1]
    cjpeg = sys.argv[2] if len(sys.argv) > 2 else "cjpeg"
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    fixtures = []
    with tempfile.TemporaryDirectory() as tmp:
        qtables = pathlib.Path(tmp) / "wide.q"
        qtables.write_text(
            "\n".join(" ".join(str(300 + i * 7 + j) for j in range(8)) for i in range(8))
            + "\n\n"
            + "\n".join(" ".join(str(400 + i * 3 + j) for j in range(8)) for i in range(8))
            + "\n"
        )
        cases = CASES + [("ext_wide_qtables", 33, 31, 3, ["-qtables", str(qtables)])]
        for seed, (name, w, h, channels, args) in enumerate(cases, start=1):
            source = pathlib.Path(tmp) / f"{name}.pnm"
            source.write_bytes(pnm(w, h, channels, seed))
            target = OUT_DIR / f"{name}.jpg"
            subprocess.run([cjpeg, *args, "-outfile", str(target), str(source)], check=True)
            result = subprocess.run([reference, str(target)], capture_output=True, text=True)
            if result.returncode != 0:
                raise SystemExit(f"reference decoder rejected {name}")
            width, height, digest = result.stdout.split()
            fixtures.append((name, target.read_bytes(), int(width), int(height), int(digest)))

    lines = ["///|", "let jpeg_fixtures : Array[(String, Bytes, Int, Int, UInt)] = ["]
    for name, data, width, height, digest in fixtures:
        lines.append(f'  ("{name}", {literal(data)}, {width}, {height}, {digest}U),')
    lines += ["]", ""]
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines))
    print(f"{len(fixtures)} fixtures")


if __name__ == "__main__":
    main()
