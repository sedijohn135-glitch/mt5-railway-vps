FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV WINEPREFIX=/root/.wine
ENV WINEDEBUG=-all

# Install all dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        software-properties-common \
        wget curl ca-certificates \
        xvfb x11vnc novnc websockify \
        fluxbox xterm unzip cabextract x11-utils \
        xdotool scrot p7zip-full \
        wine && \
    rm -rf /var/lib/apt/lists/*

# Verify wine is actually installed
RUN wine --version 2>&1 | head -3

# Make noVNC default page point to the lightweight vnc client
RUN ln -sf /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Download MetaTrader 5 installer
RUN wget -q -O /root/mt5setup.exe \
    "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

# Pre-install MT5 during build (silent install with /S)
# This avoids the "debugger found" dialog and any user clicks at runtime
RUN export DISPLAY=:99 && \
    export WINEPREFIX=/root/.wine-build && \
    export WINEDEBUG=-all && \
    Xvfb :99 -screen 0 1024x768x24 +extension RANDR & \
    XVFB_PID=$! && \
    sleep 3 && \
    echo "=== Initializing wine prefix ===" && \
    wineboot --init 2>&1 | tail -3 && \
    echo "=== Running silent install (this may take 3-5 min) ===" && \
    DISPLAY=:99 wine /root/mt5setup.exe /S 2>&1 | tail -3 && \
    echo "=== Waiting for installation to complete ===" && \
    for i in $(seq 1 120); do \
        if [ -f "/root/.wine-build/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then \
            echo "MT5 installed after $((i*5))s"; \
            break; \
        fi; \
        sleep 5; \
    done && \
    echo "=== Copying installed files ===" && \
    cp -r "/root/.wine-build/drive_c/Program Files/MetaTrader 5" /root/mt5-installed/ && \
    echo "=== Installed files ===" && \
    ls -la /root/mt5-installed/ | head -10 && \
    kill $XVFB_PID 2>/dev/null || true && \
    rm -rf /root/.wine-build

# Verify install succeeded
RUN test -f /root/mt5-installed/terminal64.exe && echo "BUILD OK: MT5 terminal64.exe is in /root/mt5-installed/" || echo "BUILD WARNING: terminal64.exe not found, will retry at runtime"

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]
