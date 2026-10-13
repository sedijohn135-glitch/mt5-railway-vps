FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y wine64 wine32 xvfb x11vnc novnc websockify fluxbox xterm wget unzip && rm -rf /var/lib/apt/lists/*
RUN ln -s /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html
RUN wget -O /root/mt5setup.exe "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PORT=8080
EXPOSE 8080
CMD ["/entrypoint.sh"]