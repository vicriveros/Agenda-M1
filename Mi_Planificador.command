:; # macOS / Linux launcher (abre directamente la app sin permisos)
:; DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
:; open "$DIR/Mi Planificador App.html" || xdg-open "$DIR/Mi Planificador App.html"
:; exit 0

@echo off
start "" "%~dp0Mi Planificador App.html"
