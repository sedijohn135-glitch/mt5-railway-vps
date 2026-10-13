#!/bin/bash
# Final entrypoint: pre-extracted MT5, no installer wizard needed

LOG=/tmp/entrypoint.log
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "[entrypoint] Container started at $(date)"
echo "=========================================="

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/wine:$PATH"
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all

# Clean up any stale X locks
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null

echo "[entrypoint] Starting Xvfb on :0..."
Xvfb :0 -screen 0 1280x800x24 +extension RANDR &
sleep 3

# Verify X is up
for i in {1..15}; do
    if xdpyinfo -display :0 >/dev/null 2>&1; then
        echo "[entrypoint] X display ready"
        break
    fi
    sleep 1
done

echo "[entrypoint] Starting window manager (fluxbox)..."
fluxbox &
sleep 1

# Create noVNC status dir
mkdir -p /usr/share/novnc 2>/dev/null
STATUS_FILE=/usr/share/novnc/status.txt

# Find terminal64.exe - either in extracted folder or in wine prefix
MT5_EXTRACTED="/root/mt5-extracted"
MT5_INSTALLED="/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"

cat > "$STATUS_FILE" <<EOF
MT5 Railway VPS Status
======================
Last update: $(date)
X server: running
Window manager: fluxbox
Wine prefix: $WINEPREFIX
EOF

echo "[entrypoint] Starting x11vnc on :5900..."
x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -forever -noxdamage &
sleep 2

# Start websockify IMMEDIATELY (no MT5 install needed since pre-extracted)
PORT=${PORT:-8080}
echo "[entrypoint] ============================================"
echo "[entrypoint] noVNC websockify starting on port $PORT"
echo "[entrypoint] ============================================"

websockify --web /usr/share/novnc 0.0.0.0:$PORT localhost:5900 &
WEBSOCKIFY_PID=$!
sleep 2

if kill -0 $WEBSOCKIFY_PID 2>/dev/null; then
    echo "[entrypoint] websockify running on PID $WEBSOCKIFY_PID"
    echo "Web UI: http://0.0.0.0:$PORT" >> "$STATUS_FILE"
fi

# Initialize wine prefix in background (needed for first run)
(
    echo "[entrypoint-bg] Initializing wine prefix..."
    if command -v wine >/dev/null 2>&1; then
        DISPLAY=:0 wineboot --init 2>&1 | tail -3 || echo "[entrypoint-bg] wineboot init returned non-zero"
    fi

    # Check for pre-extracted MT5
    echo "[entrypoint-bg] Looking for MT5 terminal binary..."
    if [ -d "$MT5_EXTRACTED" ]; then
        # Find any executable that might be the terminal
        for candidate in $(find "$MT5_EXTRACTED" -type f -name "*.exe" 2>/dev/null); do
            echo "[entrypoint-bg] Found: $candidate"
        done
    fi

    # Try to launch MT5
    if [ -f "$MT5_INSTALLED" ]; then
        echo "[entrypoint-bg] MT5 already installed in wine prefix, launching..."
        DISPLAY=:0 wine "$MT5_INSTALLED" &
        echo "MT5: running (installed)" >> "$STATUS_FILE"
    elif [ -d "$MT5_EXTRACTED" ]; then
        # Try to find and run terminal64.exe or metatrader.exe from extracted
        MT5_BIN=$(find "$MT5_EXTRACTED" -name "terminal64.exe" 2>/dev/null | head -1)
        if [ -z "$MT5_BIN" ]; then
            MT5_BIN=$(find "$MT5_EXTRACTED" -name "metatrader5*.exe" 2>/dev/null | head -1)
        fi
        if [ -z "$MT5_BIN" ]; then
            MT5_BIN=$(find "$MT5_EXTRACTED" -name "*.exe" 2>/dev/null | head -1)
        fi
        if [ -n "$MT5_BIN" ]; then
            echo "[entrypoint-bg] Launching extracted MT5: $MT5_BIN"
            DISPLAY=:0 wine "$MT5_BIN" &
            echo "MT5: running (extracted)" >> "$STATUS_FILE"
        else
            echo "[entrypoint-bg] No MT5 binary found in extracted folder"
            echo "MT5: not found" >> "$STATUS_FILE"
        fi
    else
        echo "[entrypoint-bg] MT5 not found anywhere"
        echo "MT5: missing" >> "$STATUS_FILE"
    fi
) &

echo "[entrypoint] All services started, waiting for websockify..."

# Wait for websockify (keeps container alive)
wait $WEBSOCKIFY_PID
