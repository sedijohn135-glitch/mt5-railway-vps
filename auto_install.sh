#!/bin/bash
# Auto-install script: clicks through MT5 install wizard using xdotool

LOG=/tmp/auto_install.log
exec > >(tee -a "$LOG") 2>&1

echo "[auto-install] Starting at $(date)"

# Make sure DISPLAY is set
export DISPLAY=:0

# Click helper function
click_at() {
    # click_at X Y — clicks at the given coordinates
    xdotool mousemove --window $1 $2 $3
    xdotool click 1
}

# Wait for window with title pattern
wait_for_window() {
    local pattern="$1"
    local timeout="${2:-300}"
    echo "[auto-install] Waiting for window matching: $pattern (timeout ${timeout}s)"
    for i in $(seq 1 $timeout); do
        # Try to find window
        WID=$(xdotool search --name "$pattern" 2>/dev/null | head -1)
        if [ -n "$WID" ]; then
            echo "[auto-install] Found window: $WID (after ${i}s)"
            echo "$WID"
            return 0
        fi
        sleep 1
    done
    echo "[auto-install] Timeout waiting for: $pattern"
    return 1
}

# Press a key on a window
press_key() {
    local wid="$1"
    local key="$2"
    xdotool key --window $wid "$key"
    sleep 0.5
}

# Click on a button by text
click_button() {
    local wid="$1"
    local button_text="$2"
    echo "[auto-install] Looking for button: $button_text"
    # Try to find button position via xdotool
    # For NSIS installers, the buttons are at predictable positions
    # We'll use Tab to navigate and Enter to click
    xdotool windowactivate --sync $wid
    sleep 0.5
    # Try multiple approaches
    xdotool key --window $wid "alt+$(echo $button_text | cut -c1 | tr '[:upper:]' '[:lower:]')"
    sleep 0.3
}

# Kill any running MT5 installer first
pkill -f mt5setup.exe 2>/dev/null || true
sleep 2

# Make sure the MT5 setup file exists
if [ ! -f /root/mt5setup.exe ]; then
    echo "[auto-install] ERROR: /root/mt5setup.exe not found"
    exit 1
fi

# Try silent install first
echo "[auto-install] Trying silent install with /S flag..."
DISPLAY=:0 wine /root/mt5setup.exe /S 2>&1 | tail -5 &
INSTALL_PID=$!

# Wait a bit and check if files appeared
echo "[auto-install] Waiting 30s to see if silent install works..."
sleep 30

MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
if [ -f "$MT5_PATH" ]; then
    echo "[auto-install] SUCCESS: MT5 installed silently"
    wait $INSTALL_PID 2>/dev/null
    exit 0
fi

echo "[auto-install] Silent install didn't work, falling back to GUI auto-click"

# Kill silent install
kill $INSTALL_PID 2>/dev/null || true
sleep 2
pkill -f mt5setup.exe 2>/dev/null || true
sleep 2

# Launch installer with GUI
echo "[auto-install] Launching installer with GUI for auto-click..."
DISPLAY=:0 wine /root/mt5setup.exe &
INSTALL_PID=$!

# Wait for the main installer window
WID=$(wait_for_window "MetaTrader 5 Setup" 60) || WID=$(wait_for_window "MetaTrader" 60) || WID=$(wait_for_window "Setup" 60)
if [ -z "$WID" ]; then
    echo "[auto-install] Could not find installer window, aborting"
    kill $INSTALL_PID 2>/dev/null
    exit 1
fi

# Bring window to front
xdotool windowactivate --sync $WID
sleep 2

# Strategy: use Tab + Enter to navigate
# Most NSIS installers have a default-focused "Next" button
echo "[auto-install] Pressing Enter to advance from Welcome page..."
xdotool key --window $WID "Return"
sleep 3

# Click through any "debugger found" error first
echo "[auto-install] Looking for debugger error dialog..."
sleep 2
ERR_WID=$(xdotool search --name "debugger" 2>/dev/null | head -1)
if [ -n "$ERR_WID" ]; then
    echo "[auto-install] Found debugger dialog, pressing Enter to dismiss"
    xdotool key --window $ERR_WID "Return"
    sleep 2
fi

# Now we're on the License Agreement page (if any) - press Next
echo "[auto-install] Step 1: License/Initial page - Next"
xdotool windowactivate --sync $WID
sleep 1
xdotool key --window $WID "alt+n"
sleep 2

# Settings page - Next
echo "[auto-install] Step 2: Settings page - Next"
xdotool key --window $WID "alt+n"
sleep 2

# Install page - Install
echo "[auto-install] Step 3: Install page - Install"
xdotool key --window $WID "alt+i"
sleep 2

# Wait for installation to complete (1-3 minutes)
echo "[auto-install] Step 4: Waiting for installation to complete..."
for i in $(seq 1 180); do
    if [ -f "$MT5_PATH" ]; then
        echo "[auto-install] MT5 terminal64.exe detected after ${i}*2 seconds"
        break
    fi
    sleep 2
done

# Click Finish
echo "[auto-install] Step 5: Finish"
xdotool windowactivate --sync $WID
sleep 2
xdotool key --window $WID "alt+f"
sleep 3
xdotool key --window $WID "Return"
sleep 2

# Verify
if [ -f "$MT5_PATH" ]; then
    echo "[auto-install] SUCCESS: MT5 installed at $MT5_PATH"
    # Launch MT5 terminal
    DISPLAY=:0 wine "$MT5_PATH" &
    echo "[auto-install] MT5 terminal launched"
    exit 0
else
    echo "[auto-install] FAILED: MT5 not found at $MT5_PATH"
    # Maybe installer still running, give more time
    pkill -f mt5setup.exe 2>/dev/null || true
    sleep 5
    if [ -f "$MT5_PATH" ]; then
        echo "[auto-install] MT5 found after cleanup, launching"
        DISPLAY=:0 wine "$MT5_PATH" &
        exit 0
    fi
    exit 1
fi
