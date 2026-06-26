@REM Bootstrap gobject-introspection for Windows GIR generation.
@REM
@REM Meson on Windows runs host python + extensionless g-ir-scanner, but GI is
@REM built for a pinned bootstrap python. We install a cmd wrapper, copy/patch
@REM gobject-introspection-1.0.pc under BUILD_PREFIX, and prepend that to
@REM PKG_CONFIG_PATH (see build.sh / install.sh on Unix).
@REM
@REM Sets: PATH, PYTHONPATH, GIR_PKG_CONFIG_PATH

set "GIR_PREFIX=%cd%\g-ir-prefix"
set "GIR_PY=3.12"

call conda create -p "%GIR_PREFIX%" -c defaults -y "python=%GIR_PY%" gobject-introspection glib "setuptools"
if errorlevel 1 exit /b 1

> "%BUILD_PREFIX%\Scripts\g-ir-scanner.cmd" (
  echo @ECHO OFF
  echo "%GIR_PREFIX%\python.exe" "%GIR_PREFIX%\Library\bin\g-ir-scanner" %%*
)

python "%RECIPE_DIR%\scripts\gir-setup.py" "%GIR_PREFIX%" "%BUILD_PREFIX%"
if errorlevel 1 exit /b 1

set "PYTHONPATH=%GIR_PREFIX%\Lib\site-packages;%PYTHONPATH%"
set "PATH=%BUILD_PREFIX%\Scripts;%GIR_PREFIX%\Library;%GIR_PREFIX%\Library\bin;%GIR_PREFIX%\Library\usr\bin;%PATH%"

FOR /F "delims=" %%i IN ('cygpath.exe -m "%GIR_PREFIX%"') DO set "GIR_PREFIX_M=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -m "%BUILD_PREFIX%"') DO set "BUILD_PREFIX_M=%%i"
set "GIR_PKG_CONFIG_PATH=%BUILD_PREFIX_M%/Library/lib/pkgconfig;%GIR_PREFIX_M%/Library/lib/pkgconfig"

"%BUILD_PREFIX%\Scripts\g-ir-scanner.cmd" --version
if errorlevel 1 exit /b 1
