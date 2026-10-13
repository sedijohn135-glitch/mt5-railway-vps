#!/bin/bash
set -e

LOG=/tmp/entrypoint.log
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "[entrypoint] Container started at $(date)"
echo "=========================================="

# Clean up any stale X locks from previous runs
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0

echo "[entrypoint] Initializing wine prefix (this takes ~30s first time)..."
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all
DISPLAY=:0 wineboot --init 2>&1 | tail -3 || echo "[entrypoint] wineboot returned non-zero, continuing"

echo "[entrypoint] Starting Xvfb on :0..."
Xvfb :0 -screen 0 1280x800x24 +extension RANDR &
XVFB_PID=$!
sleep 3

# Verify X is up
for i in {1..15}; do
    if xdpyinfo -display :0 >/dev/null 2>&1; then
        echo "[entrypoint] X display ready"
        break
    fi
    echo "[entrypoint] Waiting for X... ($i)"
    sleep 1
done

echo "[entrypoint] Starting window manager (fluxbox)..."
fluxbox &

# Write a status file the user can fetch
STATUS_FILE=/usr/share/novnc/status.txt
mkdir -p /usr/share/novnc
cat > "$STATUS_FILE" <<EOF
MT5 Railway VPS Status
======================
Last update: $(date)
X server: running
Window manager: fluxbox
Wine prefix: $WINEPREFIX
EOF

# Install MT5 if not already installed
MT5_PATH="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
if [ ! -f "$MT5_PATH" ]; then
    echo "[entrypoint] ============================================"
    echo "[entrypoint] MT5 not found, installing..."
    echo "[entrypoint] This will take 5-10 minutes on first run"
    echo "[entrypoint] Watch the browser — install wizard will appear"
    echo "[entrypoint] ============================================"

    # Update status
    echo "MT5 install: in progress (first run only)" >> "$STATUS_FILE"

    # Start installer — don't use silent flags, let user click through wizard
    DISPLAY=:0 wine /root/mt5setup.exe &
    INSTALL_PID=$!

    # Wait up to 10 minutes for install to complete
    for i in {1..120}; do
        if [ -f "$MT5_PATH" ]; then
            echo "[entrypoint] MT5 installation detected at iteration $i"
            break
        fi
        sleep 5
    done

    # Kill installer if still running
    if kill -0 $INSTALL_PID 2>/dev/null; then
        echo "[entrypoint] Killing installer process"
        kill $INSTALL_PID 2>/dev/null || true
        # Give it a moment, then force-kill any remaining wine processes
        sleep 2
        pkill -f "mt5setup.exe" 2>/dev/null || true
    fi
    wait $INSTALL_PID 2>/dev/null || true

    if [ ! -f "$MT5_PATH" ]; then
        echo "[entrypoint] WARNING: MT5 not found at $MT5_PATH after install attempt"
        echo "[entrypoint] Check the browser — installer may need manual clicks"
    else
        echo "[entrypoint] MT5 installed successfully"
    fi
else
    echo "[entrypoint] MT5 already installed, skipping setup"
fi

# Launch MT5 terminal in background
if [ -f "$MT5_PATH" ]; then
    echo "[entrypoint] Launching MT5 terminal..."
    DISPLAY=:0 wine "$MT5_PATH" &
    MT5_PID=$!
    echo "[entrypoint] MT5 PID: $MT5_PID"
    echo "MT5: running" >> "$STATUS_FILE"
else
    echo "[entrypoint] WARNING: MT5 not installed, terminal not started"
    echo "MT5: NOT INSTALLED" >> "$STATUS_FILE"
fi

echo "[entrypoint] Starting x11vnc on :5900..."
x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -forever -noxdamage &
X11VNC_PID=$!

sleep 2

PORT=${PORT:-8080}
echo "[entrypoint] ============================================"
echo "[entrypoint] noVNC ready on port $PORT"
echo "[entrypoint] Open your Railway domain URL in browser"
echo "[entrypoint] ============================================"

# Update status
cat >> "$STATUS_FILE" <<EOF
x11vnc: running on :5900
noVNC: http://0.0.0.0:$PORT
EOF

# Run websockify in foreground (this is the main process)
exec websockify --web /usr/share/novnc 0.0.0.0:$PORT localhost:5900
