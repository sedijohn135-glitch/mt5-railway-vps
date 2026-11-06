# MT5 for Railway: MetaTrader 5 on Wine 10, a password-protected screen in the browser (port 3000)
# and the MetaTrader5 Python API for the bots (RPyC, port 8001, private network only).
# Image: https://github.com/gmag11/MetaTrader5-Docker-Image
FROM gmag11/metatrader5_vnc:2.3

# MT5 does not use .NET: no Wine process asks for Mono (its install dialog blocked every Wine process).
ENV WINEDLLOVERRIDES=mscoree=d

# Container start: repairs a broken Wine prefix, then MT5 logs in by itself from MT5_LOGIN / MT5_PASSWORD /
# MT5_SERVER and starts with Algo Trading on.
COPY mt5-init.sh /custom-cont-init.d/50-mt5-init
ENV MT5_CMD_OPTIONS='/config:Z:\config\mt5login.ini'

# start.sh: no Mono, the current MetaTrader5 Python package instead of 5.0.36 (2021), and a marker when it is done.
ENV MT5_PY_VERSION=5.0.6231
RUN sed -i 's|^if \[ ! -e "/config/.wine/drive_c/windows/mono" \]; then|if false; then|' /Metatrader/start.sh \
    && sed -i "s/^metatrader_version=.*/metatrader_version=\"$MT5_PY_VERSION\"/" /Metatrader/start.sh \
    && grep -q '^if false; then' /Metatrader/start.sh \
    && grep -q "^metatrader_version=\"$MT5_PY_VERSION\"" /Metatrader/start.sh \
    && echo 'touch /tmp/mt5-ready' >> /Metatrader/start.sh

# The image's own bridge (mt5linux) no longer starts: mt5linux 1.1.1 does not import on Python 3.11.
COPY mt5-bridge.sh /custom-services.d/mt5-bridge

# The screen controls a trading account: never start it without a password.
ENTRYPOINT ["/bin/sh", "-c", "[ -n \"$PASSWORD\" ] || { echo 'PASSWORD missing: set it in Railway Variables' >&2; exit 1; }; exec /init"]
