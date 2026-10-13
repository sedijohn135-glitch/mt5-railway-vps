FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV WINEPREFIX=/root/.wine
ENV WINEDEBUG=-all

# Install all dependencies including 7z for MT5 extraction
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

# Pre-extract MT5 setup.exe during build (bypasses installer wizard entirely)
# This way, no GUI install, no "debugger found" dialog, no clicks needed
RUN mkdir -p /root/mt5-extracted && \
    cd /root/mt5-extracted && \
    7z x -y /root/mt5setup.exe 2>&1 | tail -5 && \
    echo "=== Extracted files ===" && \
    find /root/mt5-extracted -type f | head -20 && \
    echo "=== Looking for terminal64.exe ===" && \
    find /root/mt5-extracted -name "terminal64.exe" -o -name "metatrader5*.exe" 2>/dev/null

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]
