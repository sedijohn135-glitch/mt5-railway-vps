#!/bin/bash
Xvfb :0 -screen 0 1024x768x24 +extension RANDR &
sleep 3
fluxbox &
x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -forever -noxdamage &
websockify --web /usr/share/novnc 0.0.0.0:$PORT localhost:5900
