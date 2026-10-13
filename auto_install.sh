#!/bin/bash
# Bulletproof auto-install for MT5: disables debugger detection + uses silent + xdotool fallback

LOG=/tmp/auto_install.log
exec > >(tee -a "$LOG") 2>&1

echo "[auto-install] Starting at $(date)"

export DISPLAY=:0
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all

# Kill any existing installer
pkill -f mt5setup.exe 2>/dev/null || true
pkill -f terminal64.exe 2>/dev/null || true
sleep 2

MT5_PATH="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe"

# Step 1: Disable Wine's debugger detection in the Windows registry
# This is what triggers the "A debugger has been found running" dialog
echo "[auto-install] Disabling debugger detection in wine registry..."
DISPLAY=:0 wine reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\AeDebug" /v Debugger /t REG_SZ /d "" /f 2>/dev/null || true
DISPLAY=:0 wine reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\AeDebug" /v Auto /t REG_SZ /d "0" /f 2>/dev/null || true

# Also try via regedit import approach
cat > /tmp/disable_debugger.reg <<'EOF'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\AeDebug]
"Debugger"=""
"Auto"="0"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework]
"DbgJITDebugLaunchSetting"=dword:00000001
"DbgManagedDebugger"=""
EOF

DISPLAY=:0 wine regedit /tmp/disable_debugger.reg 2>/dev/null || true

# Step 2: Start a background "dialog dismisser" that aggressively clicks OK on any dialog
(
    echo "[dialog-dismisser] Started at $(date)"
    while true; do
        # Find ALL visible windows
        for WID in $(xdotool search --name "" 2>/dev/null); do
            # Get window name
            NAME=$(xdotool getwindowname $WID 2>/dev/null)
            if [ -z "$NAME" ]; then
                continue
            fi
            # Check if it's a dialog with OK button
            if [[ "$NAME" == *"debugger"* ]] || \
               [[ "$NAME" == *"mt5setup"* ]] || \
               [[ "$NAME" == *"MetaTrader"* ]] || \
               [[ "$NAME" == *"Error"* ]] || \
               [[ "$NAME" == *"Setup"* ]] || \
               [[ "$NAME" == *"xmessage"* ]]; then
                echo "[dialog-dismisser] Dismissing: $NAME (wid=$WID)"
                # Try multiple ways to dismiss
                xdotool windowactivate --sync $WID 2>/dev/null
                xdotool key --window $WID Return 2>/dev/null
                xdotool key --window $WID space 2>/dev/null
                xdotool key --window $WID Escape 2>/dev/null
                sleep 0.5
            fi
        done
        sleep 1
    done
) &
DIALOG_PID=$!

# Step 3: Try silent install first
echo "[auto-install] Trying silent install (no GUI)..."
if [ ! -f /root/mt5setup.exe ]; then
    echo "[auto-install] ERROR: /root/mt5setup.exe missing"
    kill $DIALOG_PID 2>/dev/null
    exit 1
fi

# Method 1: Silent install with /S
DISPLAY=:0 wine /root/mt5setup.exe /S 2>&1 | tail -3 &
INSTALL_PID=$!

# Wait up to 5 minutes for silent install to complete
echo "[auto-install] Waiting up to 5 min for silent install..."
for i in $(seq 1 150); do
    if [ -f "$MT5_PATH" ]; then
        echo "[auto-install] SUCCESS: MT5 installed silently after $((i*2))s"
        kill $INSTALL_PID 2>/dev/null
        sleep 2
        pkill -f mt5setup.exe 2>/dev/null
        kill $DIALOG_PID 2>/dev/null
        # Launch MT5
        DISPLAY=:0 wine "$MT5_PATH" &
        echo "[auto-install] MT5 launched"
        exit 0
    fi
    sleep 2
done

# Method 2: GUI install with xdotool
echo "[auto-install] Silent install taking too long, falling back to GUI auto-click..."

# Kill silent install
kill $INSTALL_PID 2>/dev/null
pkill -f mt5setup.exe 2>/dev/null
sleep 3

# Launch GUI installer
DISPLAY=:0 wine /root/mt5setup.exe &
GUI_PID=$!

# Wait for installer window
echo "[auto-install] Waiting for installer window..."
for i in $(seq 1 60); do
    WID=$(xdotool search --name "Setup" 2>/dev/null | head -1)
    if [ -n "$WID" ]; then
        echo "[auto-install] Found installer window: $WID"
        break
    fi
    WID=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
    if [ -n "$WID" ]; then
        echo "[auto-install] Found installer window: $WID"
        break
    fi
    sleep 2
done

# Click through the wizard: Next, Next, Install, Finish
for step in 1 2 3 4 5; do
    echo "[auto-install] Step $step: pressing Enter/Next"
    if [ -n "$WID" ]; then
        xdotool windowactivate --sync $WID 2>/dev/null
        xdotool key --window $WID "alt+n" 2>/dev/null
        sleep 0.5
        xdotool key --window $WID "alt+i" 2>/dev/null
        sleep 0.5
        xdotool key --window $WID "Return" 2>/dev/null
    fi
    sleep 4
done

# Final wait for installation to complete
echo "[auto-install] Final wait for MT5 install..."
for i in $(seq 1 120); do
    if [ -f "$MT5_PATH" ]; then
        echo "[auto-install] SUCCESS: MT5 installed at $MT5_PATH"
        # Launch MT5
        DISPLAY=:0 wine "$MT5_PATH" &
        sleep 2
        kill $DIALOG_PID 2>/dev/null
        exit 0
    fi
    sleep 2
done

echo "[auto-install] FAILED: MT5 not installed after 4 minutes"
echo "[auto-install] Dialog dismisser still running, user can manually click OK"
# Don't kill dialog dismisser - let user click OK if they want
exit 1
