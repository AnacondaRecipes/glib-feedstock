"""Windows gobject-introspection bootstrap helpers for glib-feedstock.

Invoked by ``gir-setup.bat`` during the Windows build (see ``bld.bat``).
Meson on Windows invokes ``g-ir-scanner`` with the host Python, but the
bootstrap GI environment is pinned to a separate prefix (``g-ir-prefix``).
This script applies the file mutations that ``gir-setup.bat`` cannot express
readably in batch: patching GI's DLL search helper and installing a patched
``gobject-introspection-1.0.pc`` under ``BUILD_PREFIX`` so the original
under ``GIR_PREFIX`` is left untouched.
"""
import argparse
import pathlib
import re
import shutil


def patch_scanner_utils(gir_prefix: pathlib.Path) -> None:
    """Fix ``g-ir-scanner`` DLL path handling on Windows.

    ``os.add_dll_directory()`` rejects relative paths (e.g. ``'.'``), which
    causes import failures when Meson runs the scanner.
    """
    utils_py = (
        gir_prefix
        / "Library/lib/gobject-introspection/giscanner/utils.py"
    )
    text = utils_py.read_text()
    text = text.replace(
        "os.add_dll_directory(path)",
        "os.add_dll_directory(os.path.abspath(path))",
    )
    utils_py.write_text(text)


def install_pc_override(gir_prefix: pathlib.Path, build_prefix: pathlib.Path) -> None:
    """Install a patched ``gobject-introspection-1.0.pc`` under ``build_prefix``.

    Copies the ``.pc`` file from the GI bootstrap env and rewrites
    ``g_ir_scanner=`` to point at ``build_prefix/Scripts/g-ir-scanner.cmd``.
    ``gnome.generate_gir()`` reads this variable from pkg-config rather than
    ``PATH``, so Meson must see the wrapper path here (with forward slashes).
    """
    src = gir_prefix / "Library/lib/pkgconfig/gobject-introspection-1.0.pc"
    dst_dir = build_prefix / "Library/lib/pkgconfig"
    dst_dir.mkdir(parents=True, exist_ok=True)
    dst = dst_dir / "gobject-introspection-1.0.pc"
    shutil.copy2(src, dst)

    wrapper = (build_prefix / "Scripts/g-ir-scanner.cmd").as_posix()
    text = dst.read_text()
    text = re.sub(
        r"^g_ir_scanner=.*$",
        f"g_ir_scanner={wrapper}",
        text,
        flags=re.M,
    )
    dst.write_text(text)


def main() -> None:
    """Patch GI utils and install the pkg-config override for ``g_ir_scanner``."""
    parser = argparse.ArgumentParser()
    parser.add_argument("gir_prefix", type=pathlib.Path)
    parser.add_argument("build_prefix", type=pathlib.Path)
    args = parser.parse_args()
    patch_scanner_utils(args.gir_prefix)
    install_pc_override(args.gir_prefix, args.build_prefix)


if __name__ == "__main__":
    main()
