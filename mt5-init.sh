#!/usr/bin/with-contenv bash
# Container start (root), before the desktop and MT5.
prefix=/config/.wine

# Make or update the Wine prefix (a new Wine version updates it) before anything else uses Wine: without a display
# no window can block it, and neither Mono nor Gecko is asked for. A prefix where nothing runs ("could not load
# kernel32.dll": a container stopped in the middle of a Wine update) is set aside and made again; start.sh then
# installs MT5 again and the login below logs it in.
wineboot() {
    s6-setuidgid abc env -u DISPLAY HOME=/config WINEPREFIX="$prefix" WINEDEBUG=-all \
        WINEDLLOVERRIDES="mscoree=d;mshtml=d" timeout 600 wine wineboot -u 2>&1
}
if wineboot | grep -q "could not load kernel32.dll"; then
    rm -rf "$prefix.broken" && mv "$prefix" "$prefix.broken"
    echo "[mt5-init] broken Wine prefix moved to $prefix.broken: MT5 is installed again" >&2
    wineboot >/dev/null
fi

# Startup config for MT5 (terminal64.exe /config:...): Algo Trading on, and the account login when
# MT5_LOGIN, MT5_PASSWORD and MT5_SERVER are set. MT5 reads it as UTF-16LE.
ini="${MT5_INI:-/config/mt5login.ini}"
{
    if [ -n "$MT5_LOGIN" ] && [ -n "$MT5_PASSWORD" ] && [ -n "$MT5_SERVER" ]; then
        printf '[Common]\r\nLogin=%s\r\nPassword=%s\r\nServer=%s\r\nKeepPrivate=1\r\nNewsEnable=0\r\n' \
            "$MT5_LOGIN" "$MT5_PASSWORD" "$MT5_SERVER"
        echo "[mt5-init] account $MT5_LOGIN on $MT5_SERVER" >&2
    else
        echo "[mt5-init] MT5_LOGIN/MT5_PASSWORD/MT5_SERVER not set: log in from the MT5 screen" >&2
    fi
    printf '[Experts]\r\nAllowLiveTrading=1\r\nAllowDllImport=0\r\nEnabled=1\r\n'
} | { printf '\377\376'; iconv -f UTF-8 -t UTF-16LE; } > "$ini"
chmod 600 "$ini"
if id abc >/dev/null 2>&1; then chown abc:abc "$ini"; fi
