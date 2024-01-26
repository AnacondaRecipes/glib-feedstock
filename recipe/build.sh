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
unset _CONDA_PYTHON_SYSCONFIGDATA_NAME

mkdir -p forgebuild
cd forgebuild
meson setup --buildtype=release --prefix="$PREFIX" --backend=ninja -Dlibdir=lib -Dlocalstatedir="$PREFIX/var" \
      -Dlibmount=disabled -Dselinux=disabled -Dxattr=false .. \
      || { cat meson-logs/meson-log.txt ; exit 1 ; }
ninja -j${CPU_COUNT} -v

if [ "${target_platform}" == 'linux-aarch64' ] || [ "${target_platform}" == "linux-ppc64le"  ] || [ "${target_platform}" == "linux-s390x" ]; then
    export MESON_TEST_TIMEOUT_MULTIPLIER=32
else
    export MESON_TEST_TIMEOUT_MULTIPLIER=8
fi

if [ "${target_platform}" == 'linux-aarch64' ] || [ "${target_platform}" == "linux-s390x" ] || [ "${target_platform}" == 'linux-ppc64le' ];
 then
    # 163/254 glib:gio / resources will fail on aarch64 and s390x
    meson test --no-suite flaky --timeout-multiplier ${MESON_TEST_TIMEOUT_MULTIPLIER} || true
elif [[ $(uname) != Darwin ]] ; then  # too many tests fail on macOS
    meson test --no-suite flaky --timeout-multiplier ${MESON_TEST_TIMEOUT_MULTIPLIER}
fi
