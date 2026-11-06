#!/usr/bin/with-contenv bash
# Startup config for MT5 (terminal64.exe /config:...): Algo Trading on, and the account login when
# MT5_LOGIN, MT5_PASSWORD and MT5_SERVER are set. MT5 reads it as UTF-16LE.
ini="${MT5_INI:-/config/mt5login.ini}"
{
    if [ -n "$MT5_LOGIN" ] && [ -n "$MT5_PASSWORD" ] && [ -n "$MT5_SERVER" ]; then
        printf '[Common]\r\nLogin=%s\r\nPassword=%s\r\nServer=%s\r\nKeepPrivate=1\r\nNewsEnable=0\r\n' \
            "$MT5_LOGIN" "$MT5_PASSWORD" "$MT5_SERVER"
        echo "[mt5-login] account $MT5_LOGIN on $MT5_SERVER" >&2
    else
        echo "[mt5-login] MT5_LOGIN/MT5_PASSWORD/MT5_SERVER not set: log in from the MT5 screen" >&2
    fi
    printf '[Experts]\r\nAllowLiveTrading=1\r\nAllowDllImport=0\r\nEnabled=1\r\n'
} | { printf '\377\376'; iconv -f UTF-8 -t UTF-16LE; } > "$ini"
chmod 600 "$ini"
if id abc >/dev/null 2>&1; then chown abc:abc "$ini"; fi
