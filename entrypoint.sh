#!/bin/bash
# Simple entrypoint: just run silent install at runtime with long timeout

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
Wine: $(wine --version 2>&1 | head -1)
EOF

echo "[entrypoint] Starting x11vnc on :5900..."
x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -forever -noxdamage &
sleep 2

# Start websockify IMMEDIATELY (Railway needs response within seconds)
PORT=${PORT:-8080}
echo "[entrypoint] noVNC websockify starting on port $PORT"
websockify --web /usr/share/novnc 0.0.0.0:$PORT localhost:5900 &
WEBSOCKIFY_PID=$!
sleep 2

if kill -0 $WEBSOCKIFY_PID 2>/dev/null; then
    echo "[entrypoint] websockify running on PID $WEBSOCKIFY_PID"
    echo "Web UI: http://0.0.0.0:$PORT" >> "$STATUS_FILE"
fi

# Background: do everything else
(
    echo "[entrypoint-bg] Initializing wine prefix (this takes ~30s)..."
    if command -v wine >/dev/null 2>&1; then
        DISPLAY=:0 wineboot --init 2>&1 | tail -3 || echo "[entrypoint-bg] wineboot init returned non-zero"
    fi

    MT5_PATH="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

    if [ -f "$MT5_PATH" ]; then
        echo "[entrypoint-bg] MT5 already installed, launching..."
        echo "MT5: starting" >> "$STATUS_FILE"
        DISPLAY=:0 wine "$MT5_PATH" &
        echo "MT5: running" >> "$STATUS_FILE"
    else
        echo "[entrypoint-bg] ============================================"
        echo "[entrypoint-bg] MT5 not found, starting silent install"
        echo "[entrypoint-bg] This takes 5-15 minutes on first run"
        echo "[entrypoint-bg] Watch /status.txt for updates"
        echo "[entrypoint-bg] ============================================"
        echo "MT5 install: started (silent, no clicks needed)" >> "$STATUS_FILE"

        # Run silent install - DON'T wait for it inline, run it in background
        # and check periodically
        DISPLAY=:0 wine /root/mt5setup.exe /S 2>&1 | tail -3 &
        INSTALL_PID=$!

        # Wait up to 20 minutes for install to complete
        for i in $(seq 1 240); do
            if [ -f "$MT5_PATH" ]; then
                echo "[entrypoint-bg] MT5 installed successfully after $((i*5))s"
                echo "MT5: installed, launching..." >> "$STATUS_FILE"
                # Wait a moment then launch
                sleep 5
                DISPLAY=:0 wine "$MT5_PATH" &
                echo "MT5: running" >> "$STATUS_FILE"
                break
            fi

            # Also check if installer process still alive
            if ! kill -0 $INSTALL_PID 2>/dev/null; then
                echo "[entrypoint-bg] Installer process exited at $((i*5))s"
                # If process exited but file not found, fail
                if [ ! -f "$MT5_PATH" ]; then
                    echo "[entrypoint-bg] MT5 not installed, trying GUI install"
                    echo "MT5: silent install failed, attempting GUI" >> "$STATUS_FILE"
                    # Last resort: launch GUI installer
                    DISPLAY=:0 wine /root/mt5setup.exe &
                    sleep 5
                fi
            fi
            sleep 5
        done

        if [ ! -f "$MT5_PATH" ]; then
            echo "[entrypoint-bg] WARNING: MT5 still not installed after 20 min"
            echo "MT5: install timeout" >> "$STATUS_FILE"
        fi
    fi
) &

echo "[entrypoint] All services started, waiting for websockify..."

# Wait for websockify (keeps container alive)
wait $WEBSOCKIFY_PID
