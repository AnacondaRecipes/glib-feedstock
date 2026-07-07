"""Post-process pkg-config files after meson install on Windows.

Called from ``install.bat`` once per split-package output.  Meson emits
``.pc`` files for the full development tree; the ``libglib`` and
``glib-tools`` outputs then prune headers, tools, and schema data.  This
script keeps the surviving ``.pc`` files consistent with what each output
actually ships.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys


# Variable lines that reference binaries or data removed from runtime outputs.
_RUNTIME_VAR_PREFIXES: dict[str, tuple[str, ...]] = {
    "glib-2.0.pc": (
        "glib_genmarshal=",
        "gobject_query=",
        "glib_mkenums=",
        "glib_valgrind_suppressions=",
    ),
    "gio-2.0.pc": (
        "schemasdir=",
        "dtdsdir=",
        "giomoduledir=",
        "gio=",
        "gio_querymodules=",
        "glib_compile_schemas=",
        "glib_compile_resources=",
        "gdbus=",
        "gdbus_codegen=",
        "gresource=",
        "gsettings=",
    ),
}

# ``Cflags`` lines that point at headers pruned from runtime outputs.
_RUNTIME_CFLAGS_PATTERNS: dict[str, tuple[re.Pattern[str], ...]] = {
    "glib-2.0.pc": (
        re.compile(r"^Cflags:.*glib-2\.0"),
    ),
    "gio-2.0.pc": (
        re.compile(r"^Cflags:"),
    ),
}

_RUNTIME_REMOVE_FILES = frozenset({"gio-windows-2.0.pc"})


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


def trim_runtime_pc(text: str, filename: str) -> str | None:
    """Drop stale variables and ``Cflags`` from a runtime-output ``.pc`` file.

    Returns ``None`` when the file should be deleted entirely.
    """
    if filename in _RUNTIME_REMOVE_FILES:
        return None

    drop_prefixes = _RUNTIME_VAR_PREFIXES.get(filename, ())
    drop_cflags = _RUNTIME_CFLAGS_PATTERNS.get(filename, ())

    out: list[str] = []
    for line in text.splitlines(keepends=True):
        stripped = line.lstrip()
        if any(stripped.startswith(prefix) for prefix in drop_prefixes):
            continue
        if any(pattern.match(stripped) for pattern in drop_cflags):
            continue
        out.append(line)
    return "".join(out)


def process_pc_dir(
    pc_dir: pathlib.Path,
    *,
    trim_runtime: bool,
) -> None:
    if not pc_dir.is_dir():
        return

    for pc_path in sorted(pc_dir.glob("*.pc")):
        text = pc_path.read_text(encoding="utf-8")
        text = strip_lintl(text)
        if trim_runtime:
            trimmed = trim_runtime_pc(text, pc_path.name)
            if trimmed is None:
                pc_path.unlink()
                continue
            text = trimmed
        pc_path.write_text(text, encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "library_prefix",
        type=pathlib.Path,
        help="Windows LIBRARY_PREFIX (e.g. $PREFIX/Library)",
    )
    parser.add_argument(
        "--trim-runtime",
        action="store_true",
        help="Prune dev-only .pc content for libglib/glib-tools outputs",
    )
    args = parser.parse_args(argv)

    pc_dir = args.library_prefix / "lib" / "pkgconfig"
    process_pc_dir(pc_dir, trim_runtime=args.trim_runtime)
    return 0


if __name__ == "__main__":
    sys.exit(main())
