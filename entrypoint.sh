#!/bin/bash
# Final entrypoint: pre-installed MT5, no installer needed at runtime

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

cat > "$STATUS_FILE" <<EOF
MT5 Railway VPS Status
======================
Last update: $(date)
X server: running
Window manager: fluxbox
EOF

echo "[entrypoint] Starting x11vnc on :5900..."
x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -forever -noxdamage &
sleep 2

# Start websockify IMMEDIATELY
PORT=${PORT:-8080}
echo "[entrypoint] noVNC websockify starting on port $PORT"

websockify --web /usr/share/novnc 0.0.0.0:$PORT localhost:5900 &
WEBSOCKIFY_PID=$!
sleep 2

if kill -0 $WEBSOCKIFY_PID 2>/dev/null; then
    echo "[entrypoint] websockify running on PID $WEBSOCKIFY_PID"
    echo "Web UI: http://0.0.0.0:$PORT" >> "$STATUS_FILE"
fi

# Background: initialize wine prefix and launch MT5 from pre-installed files
(
    echo "[entrypoint-bg] Initializing wine prefix..."
    if command -v wine >/dev/null 2>&1; then
        DISPLAY=:0 wineboot --init 2>&1 | tail -3 || echo "[entrypoint-bg] wineboot init returned non-zero"
    fi

    # Check pre-installed MT5
    if [ -f /root/mt5-installed/terminal64.exe ]; then
        echo "[entrypoint-bg] Found pre-installed MT5 at /root/mt5-installed/terminal64.exe"
        echo "MT5: starting (pre-installed)" >> "$STATUS_FILE"
        DISPLAY=:0 wine /root/mt5-installed/terminal64.exe &
        echo "[entrypoint-bg] MT5 launched"
        echo "MT5: running" >> "$STATUS_FILE"
    else
        echo "[entrypoint-bg] Pre-installed MT5 not found, falling back to silent install"
        echo "MT5: pre-install missing, running silent install" >> "$STATUS_FILE"
        DISPLAY=:0 wine /root/mt5setup.exe /S 2>&1 | tail -3 &
        INSTALL_PID=$!
        # Wait up to 5 min
        for i in $(seq 1 150); do
            if [ -f "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then
                echo "[entrypoint-bg] MT5 installed via silent install"
                echo "MT5: running" >> "$STATUS_FILE"
                break
            fi
            sleep 2
        done
        # Launch
        if [ -f "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then
            DISPLAY=:0 wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &
        fi
    fi
) &

echo "[entrypoint] All services started, waiting for websockify..."

# Wait for websockify (keeps container alive)
wait $WEBSOCKIFY_PID
