#!/bin/bash
set -e

echo "[entrypoint] Starting Xvfb on :0..."
Xvfb :0 -screen 0 1280x800x24 +extension RANDR &
sleep 3

echo "[entrypoint] Starting window manager (fluxbox)..."
fluxbox &

# Wait for X to be ready
for i in {1..20}; do
    if xdpyinfo -display :0 >/dev/null 2>&1; then
        echo "[entrypoint] X display ready"
        break
    fi
    sleep 1
done

# Install MT5 if not already installed
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
if [ ! -f "$MT5_PATH" ]; then
    echo "[entrypoint] Installing MetaTrader 5 (first run, may take a few minutes)..."
    DISPLAY=:0 wine /root/mt5setup.exe /silent /norestart &
    INSTALL_PID=$!

    # Wait up to 6 minutes for installation to finish
    for i in {1..72}; do
        if [ -f "$MT5_PATH" ]; then
            echo "[entrypoint] MT5 installation detected"
            break
        fi
        sleep 5
    done
    kill $INSTALL_PID 2>/dev/null || true
    wait $INSTALL_PID 2>/dev/null || true
else
    echo "[entrypoint] MT5 already installed, skipping setup"
fi

echo "[entrypoint] Launching MT5 terminal..."
DISPLAY=:0 wine "$MT5_PATH" &

echo "[entrypoint] Starting x11vnc on :5900..."
x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -forever -noxdamage &

sleep 2

PORT=${PORT:-8080}
echo "[entrypoint] Starting noVNC websockify on 0.0.0.0:$PORT -> localhost:5900"
exec websockify --web /usr/share/novnc 0.0.0.0:$PORT localhost:5900
