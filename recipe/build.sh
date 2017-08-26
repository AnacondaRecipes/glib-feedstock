#!/usr/bin/env bash

# Need to get appropriate response to g_get_system_data_dirs()
# See the hardcoded-paths.patch file
export CFLAGS="-DCONDA_PREFIX=\\\"${PREFIX}\\\""

if [[ ${HOST} =~ .*darwin.* ]]; then
  # Pick up the Conda version of gettext/libintl:
  export CPPFLAGS="${CPPFLAGS} -I${PREFIX}/include"
  export LDFLAGS="${LDFLAGS} -L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib"
  LIBICONV=gnu
elif [[ ${HOST} =~ .*linux.* ]]; then
  # Pick up the Conda version of gettext/libintl:
  export CPPFLAGS="${CPPFLAGS} -I${PREFIX}/include"
  export LDFLAGS="${LDFLAGS} -L${PREFIX}/lib"
  # So the system (builtin to glibc) iconv gets found and used.
  LIBICONV=maybe
fi

# A full path to PYTHON causes overly long shebang in gobject/glib-genmarshal
./configure --prefix=${PREFIX} \
            --with-python=$(basename "${PYTHON}") \
            --with-libiconv=${LIBICONV} \
            --disable-libmount \
                || { cat config.log; exit 1; }

make -j${CPU_COUNT} V=1
# FIXME
# ERROR: fileutils - too few tests run (expected 15, got 14)
# ERROR: fileutils - exited with status 134 (terminated by signal 6?)
# make check
make install

cd $PREFIX
find . -type f -name "*.la" -exec rm -rf '{}' \; -print
