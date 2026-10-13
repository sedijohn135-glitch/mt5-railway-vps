#!/bin/bash
# Don't use set -e — we want the websockify to come up even if wine/mt5 fails

LOG=/tmp/entrypoint.log
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "[entrypoint] Container started at $(date)"
echo "=========================================="

# Make sure PATH includes common locations
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/wine:$PATH"

# Clean up any stale X locks from previous runs
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null

export WINEPREFIX=/root/.wine
export WINEDEBUG=-all

echo "[entrypoint] Checking for wine..."
which wine && wine --version 2>&1 | head -1 || echo "[entrypoint] WARNING: wine not found in PATH"

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
FLUXBOX_PID=$!
sleep 1

# Create noVNC directory and status file
mkdir -p /usr/share/novnc 2>/dev/null
STATUS_FILE=/usr/share/novnc/status.txt
cat > "$STATUS_FILE" <<EOF
MT5 Railway VPS Status
======================
Last update: $(date)
X server: running
Window manager: fluxbox
Wine prefix: $WINEPREFIX
EOF

# Initialize wine prefix if wine is available
if command -v wine >/dev/null 2>&1; then
    echo "[entrypoint] Initializing wine prefix..."
    DISPLAY=:0 wineboot --init 2>&1 | tail -3 || echo "[entrypoint] wineboot init returned non-zero, continuing"

    # Install MT5 if not already installed
    MT5_PATH="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
    if [ ! -f "$MT5_PATH" ]; then
        echo "[entrypoint] ============================================"
        echo "[entrypoint] MT5 not found, installing..."
        echo "[entrypoint] Watch the browser — install wizard will appear"
        echo "[entrypoint] ============================================"
        echo "MT5 install: in progress (first run only)" >> "$STATUS_FILE"

        DISPLAY=:0 wine /root/mt5setup.exe &
        INSTALL_PID=$!

        # Wait up to 10 minutes for install
        for i in {1..120}; do
            if [ -f "$MT5_PATH" ]; then
                echo "[entrypoint] MT5 installation detected at iteration $i"
                break
            fi
            sleep 5
        done

        if kill -0 $INSTALL_PID 2>/dev/null; then
            kill $INSTALL_PID 2>/dev/null || true
            sleep 2
            pkill -f "mt5setup.exe" 2>/dev/null || true
        fi
        wait $INSTALL_PID 2>/dev/null || true

        if [ ! -f "$MT5_PATH" ]; then
            echo "[entrypoint] WARNING: MT5 not found at $MT5_PATH"
        else
            echo "[entrypoint] MT5 installed successfully"
        fi
    else
        echo "[entrypoint] MT5 already installed, skipping setup"
    fi

    # Launch MT5 terminal
    if [ -f "$MT5_PATH" ]; then
        echo "[entrypoint] Launching MT5 terminal..."
        DISPLAY=:0 wine "$MT5_PATH" &
        echo "MT5: running" >> "$STATUS_FILE"
    else
        echo "[entrypoint] WARNING: MT5 not installed, terminal not started"
        echo "MT5: NOT INSTALLED" >> "$STATUS_FILE"
    fi
else
    echo "[entrypoint] Wine not available, skipping MT5 install"
    echo "MT5: wine not installed" >> "$STATUS_FILE"
fi

echo "[entrypoint] Starting x11vnc on :5900..."
x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -forever -noxdamage &
X11VNC_PID=$!
sleep 2

PORT=${PORT:-8080}
echo "[entrypoint] ============================================"
echo "[entrypoint] noVNC websockify starting on port $PORT"
echo "[entrypoint] Open your Railway domain URL in browser"
echo "[entrypoint] ============================================"

cat >> "$STATUS_FILE" <<EOF
x11vnc: running on :5900
noVNC: http://0.0.0.0:$PORT
EOF

# CRITICAL: websockify must start and stay up
exec websockify --web /usr/share/novnc 0.0.0.0:$PORT localhost:5900
