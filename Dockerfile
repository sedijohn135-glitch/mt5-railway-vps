# MT5 for Railway: MetaTrader 5 under Wine, a password-protected screen in the browser (port 3000)
# and the MetaTrader5 Python API for the bots (RPyC, port 8001, private network only).
# Base: https://github.com/gmag11/MetaTrader5-Docker-Image (KasmVNC, start.sh installs and starts MT5).
FROM gmag11/metatrader5_vnc:2.3

# Wine 11 (WineHQ devel, pinned): current MT5 builds stop on "A debugger has been found running in your system"
# under the image's Wine 10; their protection makes direct system calls that Wine handles from 11.6 on (Wine bug 58043).
ARG WINE_PKG=11.10~bookworm-1
RUN set -eux; \
    rm -f /etc/apt/sources.list.d/winehq*; \
    curl -fsSL https://dl.winehq.org/wine-builds/winehq.key -o /etc/apt/keyrings/winehq-archive.key; \
    test "$(gpg --show-keys --with-colons /etc/apt/keyrings/winehq-archive.key | awk -F: '$1=="fpr"{print $10; exit}')" \
        = D43F640145369C51D786DDEA76F1A20FF987672F; \
    printf 'Types: deb\nURIs: https://dl.winehq.org/wine-builds/debian\nSuites: bookworm\nComponents: main\nArchitectures: amd64 i386\nSigned-By: /etc/apt/keyrings/winehq-archive.key\n' \
        > /etc/apt/sources.list.d/winehq-bookworm.sources; \
    apt-get update; \
    apt-get install -y --install-recommends "winehq-devel=$WINE_PKG" "wine-devel=$WINE_PKG" \
        "wine-devel-amd64=$WINE_PKG" "wine-devel-i386:i386=$WINE_PKG"; \
    apt-get clean; rm -rf /var/lib/apt/lists/*; \
    wine --version

# The bridge's Python: 64-bit Windows Python (embeddable: no installer runs under Wine) with MetaQuotes' MetaTrader5
# package and RPyC, installed from Linux. MetaTrader5 has no 32-bit packages since 5.0.37 (2022).
ENV MT5_PY_VERSION=5.0.6231
RUN set -eux; d=/opt/winpython; mkdir -p "$d"; \
    curl -fsSL https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip -o /tmp/py.zip; \
    python3 -m zipfile -e /tmp/py.zip "$d"; rm /tmp/py.zip; \
    printf 'python311.zip\r\n.\r\nLib\\site-packages\r\nimport site\r\n' > "$d/python311._pth"; \
    python3 -m pip install --no-cache-dir --break-system-packages --target "$d/Lib/site-packages" \
        --platform win_amd64 --python-version 3.11 --implementation cp --only-binary=:all: \
        "MetaTrader5==$MT5_PY_VERSION" "rpyc==6.0.2"; \
    test -d "$d/Lib/site-packages/MetaTrader5"; chmod -R a+rX "$d"

# MT5 does not use .NET: no Wine process asks for Mono (its install dialog blocked every Wine process).
ENV WINEDLLOVERRIDES=mscoree=d

# Container start: makes or updates the Wine prefix with no window possible, then MT5 logs in by itself from
# MT5_LOGIN / MT5_PASSWORD / MT5_SERVER and starts with Algo Trading on.
COPY mt5-init.sh /custom-cont-init.d/50-mt5-init
ENV MT5_CMD_OPTIONS='/config:Z:\config\mt5login.ini'

# start.sh installs and starts MT5, without Mono, then stops: its Python part (a 32-bit Python, and an mt5linux
# server that no longer starts: mt5linux 1.1.1 does not import on Python 3.11) is replaced by mt5-bridge.sh.
RUN sed -i 's|^if \[ ! -e "/config/.wine/drive_c/windows/mono" \]; then|if false; then|' /Metatrader/start.sh \
    && sed -i 's|^# Install Python in Wine if not present|touch /tmp/mt5-ready; exit 0\n&|' /Metatrader/start.sh \
    && grep -q '^if false; then' /Metatrader/start.sh \
    && grep -q '^touch /tmp/mt5-ready; exit 0' /Metatrader/start.sh
COPY mt5-bridge.sh /custom-services.d/mt5-bridge

# The screen controls a trading account: never start it without a password.
ENTRYPOINT ["/bin/sh", "-c", "[ -n \"$PASSWORD\" ] || { echo 'PASSWORD missing: set it in Railway Variables' >&2; exit 1; }; exec /init"]
