# MT5 for Railway: MetaTrader 5 on Wine 10, a password-protected screen in the browser (port 3000)
# and the MetaTrader5 Python API for the bots (RPyC, port 8001, private network only).
# Image: https://github.com/gmag11/MetaTrader5-Docker-Image
FROM gmag11/metatrader5_vnc:2.3

# MT5 logs in by itself from MT5_LOGIN / MT5_PASSWORD / MT5_SERVER and starts with Algo Trading on.
COPY mt5-login.sh /custom-cont-init.d/50-mt5-login
ENV MT5_CMD_OPTIONS='/config:Z:\config\mt5login.ini'

# start.sh installs the MetaTrader5 Python package in Wine: the current one instead of 5.0.36 (2021).
ENV MT5_PY_VERSION=5.0.6231
RUN sed -i "s/^metatrader_version=.*/metatrader_version=\"$MT5_PY_VERSION\"/" /Metatrader/start.sh \
    && grep -q "^metatrader_version=\"$MT5_PY_VERSION\"" /Metatrader/start.sh

# The image's own bridge (mt5linux) no longer starts: mt5linux 1.1.1 does not import on Python 3.11.
COPY mt5-bridge.sh /custom-services.d/mt5-bridge

# The screen controls a trading account: never start it without a password.
ENTRYPOINT ["/bin/sh", "-c", "[ -n \"$PASSWORD\" ] || { echo 'PASSWORD missing: set it in Railway Variables' >&2; exit 1; }; exec /init"]
