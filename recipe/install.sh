#!/bin/bash

set -ex


# --- pkg-config (CI-safe; prefers conda build env; macOS-friendly) ---
# Put fixes under this wrapper exactly as you asked
if [ "${target_platform}" = osx-* ]; then
  # Prefer conda-build tools, not system/homebrew.
  # conda-build usually provides tools in BUILD_PREFIX/bin (a.k.a. _build_env/bin)
  REAL_PKG_CONFIG=""

  # 1) Most common: pkg-config exists in build env
  if [ -x "${BUILD_PREFIX}/bin/pkg-config" ]; then
    REAL_PKG_CONFIG="${BUILD_PREFIX}/bin/pkg-config"
  # 2) Sometimes only pkgconf exists (no pkg-config alias)
  elif [ -x "${BUILD_PREFIX}/bin/pkgconf" ]; then
    REAL_PKG_CONFIG="${BUILD_PREFIX}/bin/pkgconf"
  # 3) Fallback: host prefix (less likely during install stage, but cheap to try)
  elif [ -x "${PREFIX}/bin/pkg-config" ]; then
    REAL_PKG_CONFIG="${PREFIX}/bin/pkg-config"
  elif [ -x "${PREFIX}/bin/pkgconf" ]; then
    REAL_PKG_CONFIG="${PREFIX}/bin/pkgconf"
  # 4) Last resort: PATH (may be empty on CI, but ok locally)
  elif command -v pkg-config >/dev/null 2>&1; then
    REAL_PKG_CONFIG="$(command -v pkg-config)"
  elif command -v pkgconf >/dev/null 2>&1; then
    REAL_PKG_CONFIG="$(command -v pkgconf)"
  fi

  if [ -z "${REAL_PKG_CONFIG}" ]; then
    echo "ERROR: pkg-config/pkgconf not found."
    echo "DEBUG: target_platform=${target_platform}"
    echo "DEBUG: BUILD_PREFIX=${BUILD_PREFIX}"
    echo "DEBUG: PREFIX=${PREFIX}"
    echo "DEBUG: PATH=${PATH}"
    echo "DEBUG: ls BUILD_PREFIX/bin:"
    ls -la "${BUILD_PREFIX}/bin" || true
    echo "DEBUG: ls PREFIX/bin:"
    ls -la "${PREFIX}/bin" || true
    exit 1
  fi

  # Ensure Meson (and any subprocess) can always execute "pkg-config"
  mkdir -p "${BUILD_PREFIX}/bin"
  cat > "${BUILD_PREFIX}/bin/pkg-config" <<EOF
#!/usr/bin/env sh
exec "${REAL_PKG_CONFIG}" "\$@"
EOF
  chmod +x "${BUILD_PREFIX}/bin/pkg-config"

  export PATH="${BUILD_PREFIX}/bin:${PATH}"
  export PKG_CONFIG="${BUILD_PREFIX}/bin/pkg-config"

  # Keep pkg-config search paths sane in multi-output install stage
  export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
  export PKG_CONFIG_PATH="${BUILD_PREFIX}/lib/pkgconfig:${BUILD_PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH}"
fi
# --- end pkg-config block ---

# --- Make sure Meson-cached pkg-config path exists (multi-output install stage) ---
# if command -v pkg-config >/dev/null 2>&1; then
#   REAL_PKG_CONFIG=$(command -v pkg-config)
# else
#   echo "ERROR: pkg-config not found in PATH"
#   exit 1
# fi

# Meson in your logs tries: .../_build_env/bin/pkg-config
# In install stage BUILD_PREFIX may be that _build_env prefix.
# mkdir -p "${BUILD_PREFIX}/bin"
# cat > "${BUILD_PREFIX}/bin/pkg-config" <<EOF
# #!/usr/bin/env bash
# exec "${REAL_PKG_CONFIG}" "\$@"
# EOF
# chmod +x "${BUILD_PREFIX}/bin/pkg-config"

# Put it first, so any subprocesses also see it
export PATH="${BUILD_PREFIX}/bin:${PATH}"
# --- end ---

# 2. Bootstrap gobject-introspection tools (without touching meta.yaml)
export GIR_PREFIX="${SRC_DIR}/g-ir-prefix"

if [[ ! -x "${GIR_PREFIX}/bin/g-ir-scanner" ]]; then
  # g-ir-build-tools есть только в conda-forge
  conda create -p "${GIR_PREFIX}" -y \
    -c conda-forge -c defaults \
    python gobject-introspection g-ir-build-tools
fi

# 3. Make g-ir-scanner available in PATH (Meson looking it there)
mkdir -p "${BUILD_PREFIX}/bin"
cat > "${BUILD_PREFIX}/bin/g-ir-scanner" <<'EOF'
#!/usr/bin/env bash
exec "${GIR_PREFIX}/bin/g-ir-scanner" "$@"
EOF
chmod +x "${BUILD_PREFIX}/bin/g-ir-scanner"

export PATH="${BUILD_PREFIX}/bin:${PATH}"

# 4. For Meson to help find gobject-introspection-1.0.pc
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
if [[ -d "${GIR_PREFIX}/lib/pkgconfig" ]]; then
  export PKG_CONFIG_PATH="${GIR_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
fi

# --- end ---


# echo "PKG_CONFIG=$PKG_CONFIG"
# $PKG_CONFIG --version
# $PKG_CONFIG --modversion gobject-introspection-1.0 || true
# $PKG_CONFIG --variable=g_ir_scanner gobject-introspection-1.0 || true
# which g-ir-scanner
# g-ir-scanner --version
# exit 1

unset _CONDA_PYTHON_SYSCONFIGDATA_NAME

cd builddir
ninja install || (cat meson-logs/meson-log.txt; false)
# remove libtool files
find $PREFIX -name '*.la' -delete

# gdb folder has a nested folder structure similar to our host prefix
# (255 chars) which causes installation issues so remove it.
rm -rf $PREFIX/share/gdb

if [[ "$PKG_NAME" == glib ]]; then
    # unsured about why the build prefix of the split package is appearing
    # in there, but we must remove it
    sed -i.bak "1s|^#!.*|#!${PREFIX}/bin/python|" "${PREFIX}/bin/glib-mkenums"
    sed -i.bak "1s|^#!.*|#!${PREFIX}/bin/python|" "${PREFIX}/bin/glib-genmarshal"
    sed -i.bak "1s|^#!.*|#!${PREFIX}/bin/python|" "${PREFIX}/bin/gtester-report"

    rm ${PREFIX}/bin/glib-mkenums.bak
    rm ${PREFIX}/bin/glib-genmarshal.bak
    rm ${PREFIX}/bin/gtester-report.bak

    # The remainder of the script is only for other packages. exit here with success.
    exit 0
elif [[ "$PKG_NAME" == glib-tools ]]; then
    mkdir .keep
    # We ship these binaries as part of the glib-tools package because
    # they can be depended on separately by other packages, e.g. gtk
    # (equivalent to Debian's libglib2.0-bin)
    mv $PREFIX/bin/gdbus .keep
    mv $PREFIX/bin/glib-compile-schemas .keep
else
    rm -f $PREFIX/bin/gapplication
    rm $PREFIX/bin/gio*
    rm $PREFIX/bin/gresource
    rm $PREFIX/bin/gsettings
    rm $PREFIX/share/bash-completion/completions/{gapplication,gdbus,gio,gresource,gsettings}
    # Copy the [de]activate scripts to $PREFIX/etc/conda/[de]activate.d.
    # This will allow them to be run on environment activation.
    for CHANGE in "activate" "deactivate"
    do
        mkdir -p "${PREFIX}/etc/conda/${CHANGE}.d"
        cp "${RECIPE_DIR}/scripts/${CHANGE}.sh" "${PREFIX}/etc/conda/${CHANGE}.d/${PKG_NAME}_${CHANGE}.sh"
    done
fi
    
rm $PREFIX/bin/{gdbus*,glib-*,gobject*,gtester*}
if [[ "$PKG_NAME" == glib-tools ]]; then
    mv .keep/* $PREFIX/bin
fi
rm -r $PREFIX/include/gio-* $PREFIX/include/glib-*
rm -r $PREFIX/lib/glib-*
rm -r $PREFIX/lib/lib{gmodule,glib,gobject,gthread,gio}-2.0${SHLIB_EXT}
rm -r $PREFIX/share/aclocal/{glib-*,gsettings*}
rm -r $PREFIX/share/gettext/its
rm -r $PREFIX/share/glib-*
