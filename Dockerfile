# MT5 for Railway: MetaTrader 5 on Wine 10, a password-protected screen in the browser (port 3000)
# and the MetaTrader5 Python bridge for the bots (mt5linux, port 8001, private network only).
# Image: https://github.com/gmag11/MetaTrader5-Docker-Image
FROM gmag11/metatrader5_vnc:2.3

# MT5 logs in by itself from MT5_LOGIN / MT5_PASSWORD / MT5_SERVER and starts with Algo Trading on.
COPY mt5-login.sh /custom-cont-init.d/50-mt5-login
ENV MT5_CMD_OPTIONS='/config:Z:\config\mt5login.ini'

# The screen controls a trading account: never start it without a password.
ENTRYPOINT ["/bin/sh", "-c", "[ -n \"$PASSWORD\" ] || { echo 'PASSWORD missing: set it in Railway Variables' >&2; exit 1; }; exec /init"]
