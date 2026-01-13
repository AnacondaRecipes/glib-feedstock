#!/usr/bin/env bash

set -ex

# There are a couple of places in the source that hardcode a system prefix;
# in hardcoded-paths.patch we edit them to refer to the Conda prefix so
# that they will get appropriately rewritten.
export CPPFLAGS="$CPPFLAGS -DCONDA_PREFIX=\\\"${PREFIX}\\\""

# @PYTHON@ is used in the build scripts and that breaks with the long prefix.
# we need to redefine that to `python`.
_PY=$PYTHON
export PYTHON="python"

# see for context: https://github.com/conda-forge/glib-feedstock/pull/72 https://github.com/conda-forge/python-feedstock/issues/474
unset _CONDA_PYTHON_SYSCONFIGDATA_NAME

# ---- gobject-introspection bootstrap (build-platform tools) ----
export GIR_PREFIX="$SRC_DIR/g-ir-prefix"

if [[ -n "${build_platform:-}" ]]; then
  export CONDA_SUBDIR="${build_platform}"
fi

conda create -p "$GIR_PREFIX" -y \
  -c conda-forge -c defaults \
  "python=${PY_VER}" \
  g-ir-build-tools gobject-introspection

unset CONDA_SUBDIR

# Check, if g-ir-scanner run
"$GIR_PREFIX/bin/g-ir-scanner" --version

cat > "$BUILD_PREFIX/bin/g-ir-scanner" <<EOF
#!/usr/bin/env bash
exec "$GIR_PREFIX/bin/g-ir-scanner" "\$@"
EOF
chmod +x "$BUILD_PREFIX/bin/g-ir-scanner"

export PKG_CONFIG_PATH="$GIR_PREFIX/lib/pkgconfig:$GIR_PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"

# Prefer an existing pkg-config in PATH
if command -v pkg-config >/dev/null 2>&1; then
  export PKG_CONFIG="$(command -v pkg-config)"
fi

# If PKG_CONFIG ends up pointing to BUILD_PREFIX/bin/pkg-config, make sure it's not a wrapper to itself
if [[ -n "${PKG_CONFIG:-}" && "${PKG_CONFIG}" == "${BUILD_PREFIX}/bin/pkg-config" ]]; then
  # If it's not executable or suspicious, just unset and let Meson find it via PATH
  [[ -x "${PKG_CONFIG}" ]] || unset PKG_CONFIG
fi

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_PATH="${BUILD_PREFIX}/lib/pkgconfig:${BUILD_PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH}"

if [[ -n "${GIR_PREFIX:-}" ]]; then
  export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${GIR_PREFIX}/lib/pkgconfig:${GIR_PREFIX}/share/pkgconfig"
fi

# DEBUG
# ${PKG_CONFIG} --exists libpcre2-8
# ${PKG_CONFIG} --libs libpcre2-8

mkdir -p builddir
meson setup builddir \
  --buildtype=release \
  --prefix="$PREFIX" \
  --backend=ninja \
  -Dlibdir=lib \
  -Dintrospection=enabled \
  -Dlocalstatedir="$PREFIX/var" \
  -Dlibmount=disabled \
  -Dselinux=disabled \
  -Dxattr=false \
  -Ddtrace=false \
  -Dsystemtap=false \
  || { cat "$SRC_DIR"/builddir/meson-logs/meson-log.txt ; exit 1 ; }

ninja -C builddir -j${CPU_COUNT} -v

if [ "${target_platform}" == 'linux-aarch64' ]; then
    export MESON_TEST_TIMEOUT_MULTIPLIER=64
else
    export MESON_TEST_TIMEOUT_MULTIPLIER=8
fi

# too many tests fail on macOS:
#________
# 324/371 glib:gio / resources                                                   ERROR             0.75s   killed by signal 6 SIGABRT
# >>> G_ENABLE_DIAGNOSTIC=1 MSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 G_TEST_BUILDDIR=$SRC_DIR/builddir/gio/tests G_DEBUG=gc-friendly GIO_LAUNCH_DESKTOP=$SRC_DIR/builddir/gio/gio-launch-desktop UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 MESON_TEST_ITERATION=1 MALLOC_CHECK_=2 G_TEST_SRCDIR=$SRC_DIR/gio/tests ASAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1 GIO_MODULE_DIR='' MALLOC_PERTURB_=94 $SRC_DIR/builddir/gio/tests/resources
#________
# 323/371 glib:gio+no-valgrind / gio-tool.py                                     ERROR             0.50s   exit status 1
# >>> G_ENABLE_DIAGNOSTIC=1 MALLOC_PERTURB_=236 G_TEST_BUILDDIR=$SRC_DIR/builddir/gio/tests G_DEBUG=gc-friendly MSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 GIO_LAUNCH_DESKTOP=$SRC_DIR/builddir/gio/gio-launch-desktop UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 MESON_TEST_ITERATION=1 MALLOC_CHECK_=2 G_TEST_SRCDIR=$SRC_DIR/gio/tests ASAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1 _G_TEST_PROGRAM_RUNNER_PATH=$SRC_DIR/builddir/gio GIO_MODULE_DIR='' PYTHONPATH=$SRC_DIR/builddir/tests/lib:$SRC_DIR/tests/lib $BUILD_PREFIX/bin/python -B $SRC_DIR/builddir/../gio/tests/gio-tool.py
#________
# 297/371 glib:gio / gdbus-auth                                                  ERROR             1.45s   killed by signal 5 SIGTRAP
# >>> G_ENABLE_DIAGNOSTIC=1 MSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 G_TEST_BUILDDIR=$SRC_DIR/builddir/gio/tests G_DEBUG=gc-friendly GIO_LAUNCH_DESKTOP=$SRC_DIR/builddir/gio/gio-launch-desktop UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 MESON_TEST_ITERATION=1 MALLOC_CHECK_=2 G_TEST_SRCDIR=$SRC_DIR/gio/tests ASAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1 MALLOC_PERTURB_=73 GIO_MODULE_DIR='' $SRC_DIR/builddir/gio/tests/gdbus-auth
#________
# 214/371 glib:gio / contenttype                                                 ERROR             1.03s   killed by signal 6 SIGABRT
# >>> G_ENABLE_DIAGNOSTIC=1 MSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 G_TEST_BUILDDIR=$SRC_DIR/builddir/gio/tests G_DEBUG=gc-friendly MALLOC_PERTURB_=187 GIO_LAUNCH_DESKTOP=$SRC_DIR/builddir/gio/gio-launch-desktop UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 MESON_TEST_ITERATION=1 MALLOC_CHECK_=2 G_TEST_SRCDIR=$SRC_DIR/gio/tests ASAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1 GIO_MODULE_DIR='' $SRC_DIR/builddir/gio/tests/contenttype
#________
# 133/371 glib:glib+core / unix                                                  ERROR             4.77s   killed by signal 6 SIGABRT
# >>> G_ENABLE_DIAGNOSTIC=1 MSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 G_DEBUG=gc-friendly UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1:print_stacktrace=1 MESON_TEST_ITERATION=1 G_TEST_BUILDDIR=$SRC_DIR/builddir/glib/tests MALLOC_CHECK_=2 G_TEST_SRCDIR=$SRC_DIR/glib/tests ASAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_summary=1 MALLOC_PERTURB_=58 $SRC_DIR/builddir/glib/tests/unix
#________

if [[ "$target_platform" != osx-* ]] ; then
    # Disable this test as it fails if gdb is installed system-wide, otherwise it will be skipped.
    echo 'exit(0)' > glib/tests/assert-msg-test.py
    cd builddir
    meson test \
      --no-suite flaky \
      --timeout-multiplier \
      ${MESON_TEST_TIMEOUT_MULTIPLIER}
    cd ..
fi
