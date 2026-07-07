"""Post-process pkg-config files after meson install on Windows.

Called from ``install.bat`` for every split-package output.  Meson emits
``-lintl`` in ``Libs`` / ``Libs.private`` lines because libintl is linked
on Windows, but intl is statically linked into GLib and must not be
advertised to downstream consumers.
"""
from __future__ import annotations

import argparse
import pathlib
import sys


def _normalize_libs_line(line: str) -> str:
    key, sep, value = line.partition(":")
    if not sep or key not in ("Libs", "Libs.private"):
        return line
    value = " ".join(value.split())
    newline = "\n"
    if line.endswith("\r\n"):
        newline = "\r\n"
    elif not line.endswith("\n"):
        newline = ""
    return f"{key}: {value}{newline}"


def strip_lintl(text: str) -> str:
    """Remove ``-lintl`` from every ``Libs`` / ``Libs.private`` line."""
    out: list[str] = []
    for line in text.splitlines(keepends=True):
        if line.startswith(("Libs:", "Libs.private:")):
            line = line.replace("-lintl", "")
            line = _normalize_libs_line(line)
        out.append(line)
    return "".join(out)


def process_pc_dir(pc_dir: pathlib.Path) -> None:
    if not pc_dir.is_dir():
        return

    for pc_path in sorted(pc_dir.glob("*.pc")):
        text = strip_lintl(pc_path.read_text(encoding="utf-8"))
        pc_path.write_text(text, encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "library_prefix",
        type=pathlib.Path,
        help="Windows LIBRARY_PREFIX (e.g. $PREFIX/Library)",
    )
    args = parser.parse_args(argv)

    pc_dir = args.library_prefix / "lib" / "pkgconfig"
    process_pc_dir(pc_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
