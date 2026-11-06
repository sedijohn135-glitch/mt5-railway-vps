#!/usr/bin/with-contenv bash
# MetaTrader5 Python API for the bots: an RPyC classic server in a 64-bit Python inside Wine, port 8001.
# Private network only: whoever reaches this port controls the trading account. s6 restarts it when it exits.
export HOME=/config WINEPREFIX=/config/.wine WINEDEBUG=-all
py='C:\Py64\python.exe'  # 64-bit: MetaTrader5 has no 32-bit packages since 5.0.37 (2022)
# Wine is left to /Metatrader/start.sh until MT5 runs: a second Wine process during its installs
# once opened a dialog that blocked every Wine process.
until [ -e /tmp/mt5-ready ]; do sleep 10; done
if [ ! -e /config/.wine/drive_c/Py64/python.exe ]; then
    curl -sSfL -o /tmp/py64.exe https://www.python.org/ftp/python/3.9.13/python-3.9.13-amd64.exe
    s6-setuidgid abc wine /tmp/py64.exe /quiet InstallAllUsers=1 'TargetDir=C:\Py64' PrependPath=0 Include_test=0 \
        Include_launcher=0
fi
s6-setuidgid abc wine "$py" -m pip install -q --disable-pip-version-check "MetaTrader5==$MT5_PY_VERSION" "rpyc==6.0.2"
echo "[mt5-bridge] MetaTrader5 $MT5_PY_VERSION, listening on port 8001"
exec s6-setuidgid abc wine "$py" -c "from rpyc.cli.rpyc_classic import ClassicServer; ClassicServer.run()" \
    --host 0.0.0.0 --port 8001
