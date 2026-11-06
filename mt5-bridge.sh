#!/usr/bin/with-contenv bash
# MetaTrader5 Python API for the bots: an RPyC classic server inside Wine's Python, port 8001.
# Private network only: whoever reaches this port controls the trading account. s6 restarts it when it exits.
export HOME=/config WINEPREFIX=/config/.wine WINEDEBUG=-all
# First start: /Metatrader/start.sh installs Python and the MetaTrader5 package in Wine. Wait for them.
until s6-setuidgid abc wine python -c "import rpyc, MetaTrader5; assert MetaTrader5.__version__ == '$MT5_PY_VERSION'" >/dev/null 2>&1; do
    sleep 20
done
echo "[mt5-bridge] MetaTrader5 $MT5_PY_VERSION, listening on port 8001"
exec s6-setuidgid abc wine python -c "from rpyc.cli.rpyc_classic import ClassicServer; ClassicServer.run()" --host 0.0.0.0 --port 8001
