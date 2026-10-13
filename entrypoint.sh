#!/bin/bash
Xvfb :0 -screen 0 1024x768x24 &
sleep 2
fluxbox &
x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -ncache_cr -forever &
websockify --web /usr/share/novnc 0.0.0.0:$PORT localhost:5900