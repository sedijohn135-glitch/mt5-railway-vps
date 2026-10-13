FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV WINEPREFIX=/root/.wine
ENV WINEDEBUG=-all

# Install base dependencies first
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg wget \
        xvfb x11vnc novnc websockify \
        fluxbox xterm unzip cabextract x11-utils && \
    rm -rf /var/lib/apt/lists/*

# Add WineHQ repository and install wine
RUN mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    echo "deb [signed-by=/etc/apt/keyrings/winehq-archive.key] https://dl.winehq.org/ubuntu focal main" > /etc/apt/sources.list.d/winehq-focal.sources && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends winehq-stable && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/bin/wine /usr/bin/wineboot || true

# Verify wine installation
RUN wine --version && wineboot --version

# Make noVNC default page point to the lightweight vnc client
RUN ln -sf /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Download MetaTrader 5 installer
RUN wget -q -O /root/mt5setup.exe \
    "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]
