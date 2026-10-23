#!/usr/bin/env bash
# Fase 11 B · 滑 audio/vídeo en sincronía: vídeo de 30 fps con un destello blanco y un pitido de 1 kHz a la vez, cada
# segundo. Se abre en mpv a pantalla completa; enciende Fluido (Mod+Alt+F) con «Sincronizar audio» encendido y apagado
# (Ajustes › 滑 Vídeo fluido) y mira si el pitido llega con el destello. Salir: q.
set -euo pipefail
cache="${XDG_CACHE_HOME:-$HOME/.cache}/ocarinashell/fluido-test"
mkdir -p "$cache"
v="$cache/av30.mp4"
if [[ ! -f "$v" ]]; then
  ffmpeg -loglevel error -y \
    -f lavfi -i "color=c=black:size=1920x1080:rate=30,drawbox=enable='lt(mod(t,1),0.0667)':x=0:y=0:w=iw:h=ih:color=white:t=fill" \
    -f lavfi -i "sine=frequency=1000:sample_rate=48000,volume='if(lt(mod(t,1),0.05),0.5,0)':eval=frame" \
    -t 120 -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac -shortest "$v"
fi
exec mpv --fs --loop "$v"
