#!/usr/bin/with-contenv bash
# MetaTrader5 Python API for the bots: an RPyC classic server in the image's 64-bit Windows Python, port 8001.
# Private network only: whoever reaches this port controls the trading account. s6 restarts it when it exits.
export HOME=/config WINEPREFIX=/config/.wine WINEDEBUG=-all PYTHONDONTWRITEBYTECODE=1
# Wine is left to /Metatrader/start.sh until MT5 runs.
until [ -e /tmp/mt5-ready ]; do sleep 10; done
echo "[mt5-bridge] MetaTrader5 $MT5_PY_VERSION, port 8001"
exec s6-setuidgid abc wine 'Z:\opt\winpython\python.exe' -c "
from rpyc.core.service import SlaveService
from rpyc.utils.server import ThreadedServer
ThreadedServer(SlaveService, hostname='0.0.0.0', port=8001, reuse_addr=True).start()"
