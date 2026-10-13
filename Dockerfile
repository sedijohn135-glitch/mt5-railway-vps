FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV WINEPREFIX=/root/.wine
ENV WINEDEBUG=-all

# Install all dependencies including wine, xdotool for auto-install
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        software-properties-common \
        wget curl ca-certificates \
        xvfb x11vnc novnc websockify \
        fluxbox xterm unzip cabextract x11-utils \
        xdotool scrot \
        wine && \
    rm -rf /var/lib/apt/lists/*

# Verify wine is actually installed
RUN wine --version 2>&1 | head -3

# Make noVNC default page point to the lightweight vnc client
RUN ln -sf /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Download MetaTrader 5 installer
RUN wget -q -O /root/mt5setup.exe \
    "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

# Copy auto-install script
COPY auto_install.sh /root/auto_install.sh
RUN chmod +x /root/auto_install.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]
