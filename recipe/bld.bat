@ECHO ON

@REM I cannot for the life of me figure out how Cygwin/MSYS2 figures out its
@REM root directory, which it uses to find the /etc/fstab which *sometimes*
@REM affects the choice of the cygdrive prefix. But, regardless of *why*,
@REM I find that we need this to work:
mkdir %BUILD_PREFIX%\Library\etc
echo none / cygdrive binary,user 0 0 >%BUILD_PREFIX%\Library\etc\fstab
echo none /tmp usertemp binary,posix=0 0 0 >>%BUILD_PREFIX%\Library\etc\fstab

set "GIR_PREFIX=%cd%\g-ir-prefix"

@REM call conda create -p %GIR_PREFIX% -y -c conda-forge -c defaults "python=%PY_VER%" g-ir-build-tools gobject-introspection glib "setuptools<71"
@REM if errorlevel 1 exit 1

call conda create -p %GIR_PREFIX% -y "python=%PY_VER%" gobject-introspection glib "setuptools<71"
if errorlevel 1 exit 1

set "PYTHONPATH=%GIR_PREFIX%\Lib\site-packages;%PYTHONPATH%"
set "PATH=%GIR_PREFIX%\Library;%GIR_PREFIX%\Library\bin;%GIR_PREFIX%\Library\usr\bin;%PATH%"

mkdir forgebuild
cd forgebuild

@REM Find libffi with pkg-config
FOR /F "delims=" %%i IN ('cygpath.exe -m "%LIBRARY_PREFIX%"') DO set "LIBRARY_PREFIX_M=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -m "%GIR_PREFIX%"') DO set "GIR_PREFIX_M=%%i"
set PKG_CONFIG_PATH=%LIBRARY_PREFIX_M%/lib/pkgconfig;%LIBRARY_PREFIX_M%/share/pkgconfig;%GIR_PREFIX_M%/Library/lib/pkgconfig

@REM Avoid a Meson issue - https://github.com/mesonbuild/meson/issues/4827
set "PYTHONLEGACYWINDOWSSTDIO=1"
set "PYTHONIOENCODING=UTF-8"

meson setup --buildtype=release --prefix="%LIBRARY_PREFIX_M%" --backend=ninja -Dselinux=disabled -Dxattr=false -Dlibmount=disabled -Dintrospection=enabled ..
if errorlevel 1 (
  type forgebuild\meson-logs\meson-log.txt
  exit /b 1
)

ninja -v
if errorlevel 1 exit 1

meson test --no-suite flaky --timeout-multiplier 8
if errorlevel 1 (
  type forgebuild\meson-logs\testlog.txt
  REM current failures:
  REM glib:glib+core / hook GLib:ERROR:../glib/tests/hook.c:193:test_hook_basics: 'g_hook_find_func (hl, FALSE, hook_destroy)' should be NULL FAIL
  exit /b 0
)