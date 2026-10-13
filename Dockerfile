FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wine64 wine32 \
        xvfb x11vnc novnc websockify \
        fluxbox xterm wget unzip cabextract x11-utils && \
    rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

RUN wget -q -O /root/mt5setup.exe \
    "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]
