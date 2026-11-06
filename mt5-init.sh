#!/usr/bin/with-contenv bash
# Container start (root), before the desktop and MT5.
prefix=/config/.wine

# Make or update the Wine prefix (a new Wine version updates it) before anything else uses Wine: without a display
# no window can block it, and neither Mono nor Gecko is asked for. A prefix where nothing runs ("could not load
# kernel32.dll": a container stopped in the middle of a Wine update) is removed and made again; start.sh then
# installs MT5 again and the login below logs it in.
wineboot() {  # output to a file: Wine's background processes would keep a pipe open
    s6-setuidgid abc env -u DISPLAY HOME=/config WINEPREFIX="$prefix" WINEDEBUG=-all \
        WINEDLLOVERRIDES="mscoree=d;mshtml=d" timeout 600 wine wineboot -u > /tmp/wineboot.log 2>&1
}
wineboot
if grep -q "could not load kernel32.dll" /tmp/wineboot.log; then
    rm -rf "$prefix"
    echo "[mt5-init] broken Wine prefix removed: MT5 is installed again" >&2
    wineboot
fi
rm -rf "$prefix.broken"   # kept by an earlier version of this script: GBs of the volume for nothing

# The volume is 5 GB at most on Railway Hobby. What MT5 downloads again when it needs it goes at boot (tick caches,
# the history of MetaQuotes-Demo, the server before the login), with the temp folders, Wine's installer cache and the
# Pythons that earlier versions of this image installed (the bridge runs on /opt/winpython). Disk use goes to the log.
bases="$prefix/drive_c/Program Files/MetaTrader 5/Bases"
usage() { du -xh -d 6 /config 2>/dev/null | sort -h | tail -n "$2" | sed "s|^|[mt5-init] disk $1: |" >&2; }
usage before 1
rm -rf /config/.cache/wine /config/.local/lib/python3.* "${prefix:?}/drive_c/Py64" \
    "${prefix:?}/drive_c/Program Files (x86)/Python39-32" "${prefix:?}/drive_c/ProgramData/Package Cache" \
    "${bases:?}/MetaQuotes-Demo" "${bases:?}/"*/ticks
rm -rf "${prefix:?}/drive_c/windows/temp/"* "${prefix:?}/drive_c/users/abc/AppData/Local/Temp/"* 2>/dev/null
usage after 8

# Startup config for MT5 (terminal64.exe /config:...): Algo Trading on, and the account login when
# MT5_LOGIN, MT5_PASSWORD and MT5_SERVER are set. MT5 reads it as UTF-16LE.
ini="${MT5_INI:-/config/mt5login.ini}"
{
    if [ -n "$MT5_LOGIN" ] && [ -n "$MT5_PASSWORD" ] && [ -n "$MT5_SERVER" ]; then
        printf '[Common]\r\nLogin=%s\r\nPassword=%s\r\nServer=%s\r\nKeepPrivate=1\r\nNewsEnable=0\r\n' \
            "$MT5_LOGIN" "$MT5_PASSWORD" "$MT5_SERVER"
        echo "[mt5-init] login from MT5_LOGIN, MT5_PASSWORD, MT5_SERVER" >&2  # never their values in the logs
    else
        echo "[mt5-init] MT5_LOGIN/MT5_PASSWORD/MT5_SERVER not set: log in from the MT5 screen" >&2
    fi
    printf '[Experts]\r\nAllowLiveTrading=1\r\nAllowDllImport=0\r\nEnabled=1\r\n'
} | { printf '\377\376'; iconv -f UTF-8 -t UTF-16LE; } > "$ini"
chmod 600 "$ini"
if id abc >/dev/null 2>&1; then chown abc:abc "$ini"; fi
