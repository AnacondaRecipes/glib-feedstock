set "GIR_PREFIX=%cd%\g-ir-prefix"

REM _build_env is recreated before install scripts run, so recreate the GIR
REM wrapper (see install.sh on Unix).
> "%BUILD_PREFIX%\Scripts\g-ir-scanner.cmd" (
  echo @ECHO OFF
  echo "%GIR_PREFIX%\python.exe" "%GIR_PREFIX%\Library\bin\g-ir-scanner" %%*
)

python -c "import re,pathlib; pc=pathlib.Path(r'%GIR_PREFIX%\Library\lib\pkgconfig\gobject-introspection-1.0.pc'); w=pathlib.Path(r'%BUILD_PREFIX%\Scripts\g-ir-scanner.cmd').as_posix(); t=pc.read_text(); t=re.sub(r'^g_ir_scanner=.*$', 'g_ir_scanner='+w, t, flags=re.M); pc.write_text(t)"

set "PYTHONPATH=%GIR_PREFIX%\Lib\site-packages;%PYTHONPATH%"
set "PATH=%BUILD_PREFIX%\Scripts;%GIR_PREFIX%\Library;%GIR_PREFIX%\Library\bin;%GIR_PREFIX%\Library\usr\bin;%PATH%"
FOR /F "delims=" %%i IN ('cygpath.exe -m "%LIBRARY_PREFIX%"') DO set "LIBRARY_PREFIX_M=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -m "%GIR_PREFIX%"') DO set "GIR_PREFIX_M=%%i"
set PKG_CONFIG_PATH=%LIBRARY_PREFIX_M%/lib/pkgconfig;%LIBRARY_PREFIX_M%/share/pkgconfig;%GIR_PREFIX_M%/Library/lib/pkgconfig

cd forgebuild
meson install --no-rebuild
if errorlevel 1 exit 1

if NOT [%PKG_NAME%] == [glib] (
  if [%PKG_NAME%] == [libglib] (
      del %LIBRARY_PREFIX%\bin\gdbus.exe
      if errorlevel 1 exit 1
      del %LIBRARY_PREFIX%\bin\gio-querymodules.exe
      if errorlevel 1 exit 1
      del %LIBRARY_PREFIX%\bin\gio.exe
      if errorlevel 1 exit 1
      del %LIBRARY_PREFIX%\bin\glib-compile-schemas.exe
      if errorlevel 1 exit 1
      del %LIBRARY_PREFIX%\bin\gresource.exe
      if errorlevel 1 exit 1
      del %LIBRARY_PREFIX%\bin\gsettings.exe
      if errorlevel 1 exit 1
  )
  del %LIBRARY_PREFIX%\bin\gdbus-codegen
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\bin\glib-compile-resources.exe
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\bin\glib-genmarshal
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\bin\glib-gettextize
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\bin\glib-mkenums
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\bin\gobject-query.exe
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\bin\gtester*
  if errorlevel 1 exit 1

  rmdir /s /q %LIBRARY_PREFIX%\include\gio-win32-2.0
  if errorlevel 1 exit 1
  rmdir /s /q %LIBRARY_PREFIX%\include\glib-2.0
  if errorlevel 1 exit 1

  rmdir /s /q %LIBRARY_PREFIX%\lib\glib-2.0\include
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\lib\pkgconfig\gio-*
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\lib\pkgconfig\glib-*
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\lib\pkgconfig\gmodule-*
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\lib\pkgconfig\gobject-*
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\lib\pkgconfig\gthread-*
  if errorlevel 1 exit 1

  del %LIBRARY_PREFIX%\share\aclocal\glib-*
  if errorlevel 1 exit 1
  del %LIBRARY_PREFIX%\share\aclocal\gsettings.m4
  if errorlevel 1 exit 1
  rmdir /s /q %LIBRARY_PREFIX%\share\gettext\its
  if errorlevel 1 exit 1
  rmdir /s /q %LIBRARY_PREFIX%\share\glib-2.0
  if errorlevel 1 exit 1
)

rem We don't have bash as a dependency so these shouldn't exist, but
rem sometimes a system bash will be picked up and they will get installed.
rem Just delete them, but don't check for errors in case they do not exist.
rem If we do want them in the future, they should go in glib-tools.
del %LIBRARY_PREFIX%\share\bash-completion\completions\gapplication
del %LIBRARY_PREFIX%\share\bash-completion\completions\gdbus
del %LIBRARY_PREFIX%\share\bash-completion\completions\gio
del %LIBRARY_PREFIX%\share\bash-completion\completions\gresource
del %LIBRARY_PREFIX%\share\bash-completion\completions\gsettings

del %LIBRARY_PREFIX%\bin\*.pdb
