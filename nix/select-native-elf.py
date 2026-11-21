"""List host Linux/glibc ELF files; leave foreign prebuilds untouched."""
import os
from pathlib import Path
import struct
import sys

root = Path(sys.argv[1])
machine = {"aarch64-linux": 183, "x86_64-linux": 62}[sys.argv[2]]
for path in sorted(root.rglob("*")):
    if path.is_symlink() or not path.is_file():
        continue
    relative = path.relative_to(root).as_posix()
    if "android" in relative or "musl" in relative:
        continue
    with path.open("rb") as stream:
        header = stream.read(20)
    if header[:4] != b"\x7fELF":
        continue
    endian = "<" if header[5] == 1 else ">"
    if struct.unpack_from(endian + "H", header, 18)[0] == machine:
        sys.stdout.buffer.write(os.fsencode(path) + b"\0")
