#!/usr/bin/env bash

if [[ ${HOST} =~ .*darwin.* ]]; then
  # Need to get appropriate response to g_get_system_data_dirs()
  # See the hardcoded-paths.patch file
  export CFLAGS="$CFLAGS -DCONDA_PREFIX=\\\"${PREFIX}\\\""
  LIBICONV=gnu
elif [[ ${HOST} =~ .*linux.* ]]; then
  # So the system (builtin to glibc) iconv gets found and used.
  LIBICONV=maybe
  export PATH="$PATH:$PREFIX/$HOST/sysroot/usr/bin"
fi

# A full path to PYTHON causes overly long shebang in gobject/glib-genmarshal
./configure --prefix=${PREFIX} \
            --host=$HOST \
            --with-python=$(basename "${PYTHON}") \
            --with-libiconv=${LIBICONV} \
            --disable-libmount \
                || { cat config.log; exit 1; }

make -j${CPU_COUNT} ${VERBOSE_AT}
# FIXME
# ERROR: fileutils - too few tests run (expected 15, got 14)
# ERROR: fileutils - exited with status 134 (terminated by signal 6?)
make check
make install
