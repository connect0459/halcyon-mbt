#!/usr/bin/env python3
"""Generate PNG decoder test fixtures from testdata/png/pngsuite.

Every image is decoded by the libpng reference program built from
tools/png_reference.c. Images libpng rejects become expected errors.

Usage: tools/gen_png_fixtures.py PATH_TO_PNG_REFERENCE_BINARY
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SUITE = ROOT / "testdata" / "png" / "pngsuite"
OUTPUT = ROOT / "src" / "decode" / "png" / "pngsuite_fixtures_test.mbt"


def literal(data: bytes) -> str:
    return 'b"' + "".join("\\x%02x" % byte for byte in data) + '"'


def main() -> None:
    reference = sys.argv[1]
    valid, invalid = [], []
    for path in sorted(SUITE.glob("*.png")):
        result = subprocess.run([reference, str(path)], capture_output=True, text=True)
        data = path.read_bytes()
        if result.returncode == 0:
            width, height, digest = result.stdout.split()
            valid.append((path.stem, data, int(width), int(height), int(digest)))
        else:
            invalid.append((path.stem, data))

    lines = ["///|", "let pngsuite_valid : Array[(String, Bytes, Int, Int, UInt)] = ["]
    for name, data, width, height, digest in valid:
        lines.append(f'  ("{name}", {literal(data)}, {width}, {height}, {digest}U),')
    lines += ["]", "", "///|", "let pngsuite_invalid : Array[(String, Bytes)] = ["]
    for name, data in invalid:
        lines.append(f'  ("{name}", {literal(data)}),')
    lines += ["]", ""]
    OUTPUT.write_text("\n".join(lines))
    print(f"{len(valid)} valid, {len(invalid)} invalid")


if __name__ == "__main__":
    main()
