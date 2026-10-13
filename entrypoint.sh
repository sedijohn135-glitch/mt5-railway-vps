#!/bin/bash
# Critical: websockify must start FIRST so Railway doesn't timeout during MT5 install

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

echo "[entrypoint] Checking for wine..."
which wine && wine --version 2>&1 | head -1 || echo "[entrypoint] WARNING: wine not found"

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
Wine prefix: $WINEPREFIX
EOF

echo "[entrypoint] Starting x11vnc on :5900..."
x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -forever -noxdamage &
sleep 2

# CRITICAL: Start websockify NOW (before MT5 install) so Railway gets a response
PORT=${PORT:-8080}
echo "[entrypoint] ============================================"
echo "[entrypoint] noVNC websockify starting on port $PORT"
echo "[entrypoint] Open Railway domain URL in browser NOW"
echo "[entrypoint] ============================================"

# Run websockify in background so we can continue with MT5 install
websockify --web /usr/share/novnc 0.0.0.0:$PORT localhost:5900 &
WEBSOCKIFY_PID=$!
sleep 2

if kill -0 $WEBSOCKIFY_PID 2>/dev/null; then
    echo "[entrypoint] websockify running on PID $WEBSOCKIFY_PID"
    echo "Web UI: http://0.0.0.0:$PORT" >> "$STATUS_FILE"
else
    echo "[entrypoint] ERROR: websockify failed to start"
fi

# Now do the slow stuff (MT5 install) in background
(
    echo "[entrypoint-bg] Initializing wine prefix..."
    if command -v wine >/dev/null 2>&1; then
        DISPLAY=:0 wineboot --init 2>&1 | tail -3 || echo "[entrypoint-bg] wineboot init returned non-zero"

        MT5_PATH="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"
        if [ ! -f "$MT5_PATH" ]; then
            echo "[entrypoint-bg] ============================================"
            echo "[entrypoint-bg] MT5 not found, starting auto-install..."
            echo "[entrypoint-bg] ============================================"
            echo "MT5 install: starting (auto-mode)" >> "$STATUS_FILE"

            # Run the auto-install script
            bash /root/auto_install.sh

            if [ -f "$MT5_PATH" ]; then
                echo "[entrypoint-bg] MT5 installed, ensuring terminal is running..."
                # Make sure MT5 is running
                if ! pgrep -f "terminal64.exe" >/dev/null 2>&1; then
                    DISPLAY=:0 wine "$MT5_PATH" &
                fi
                echo "MT5: running" >> "$STATUS_FILE"
            else
                echo "[entrypoint-bg] MT5 install did not complete"
                echo "MT5: install incomplete - check status.txt" >> "$STATUS_FILE"
            fi
        else
            echo "[entrypoint-bg] MT5 already installed, launching terminal..."
            DISPLAY=:0 wine "$MT5_PATH" &
            echo "MT5: running" >> "$STATUS_FILE"
        fi
    else
        echo "[entrypoint-bg] wine not available, skipping MT5"
        echo "MT5: wine missing" >> "$STATUS_FILE"
    fi
) &

echo "[entrypoint] Background MT5 install started, foreground waiting for websockify..."

# Wait for websockify (this keeps the container alive)
wait $WEBSOCKIFY_PID
