#!/bin/zsh
# Assembles the Hyperia City Enchanted reel from the stills make_hyperia_images.py renders.
#   zsh marketing/3.5/src/make_hyperia_reel.sh
# Title → 18 Enchanteds → 2 Iconics → end card. Each still gets a slow push-in
# (rendered at 2x so the zoom stays smooth). The cards hard-cut, so the edit lands
# on the beat of whatever trending audio gets added in the IG composer. Silent by design.
set -euo pipefail
cd "$(dirname "$0")/../../drafts/reels/2026-10-16"
rm -rf segments && mkdir -p segments

stills=(stills/*.png)
last=${#stills[@]}
: > segments/list.txt
i=0
for still in "${stills[@]}"; do
  i=$(( i + 1 ))
  if (( i == 1 )); then secs=2.4      # title
  elif (( i == last )); then secs=2.6 # end card
  elif (( i >= last - 2 )); then secs=1.6 # Iconics linger
  else secs=1.0; fi
  frames=$(( ${secs%.*} * 30 + ${secs#*.} * 3 ))
  ffmpeg -y -loglevel error -loop 1 -i "$still" -t "$secs" \
    -vf "scale=2160:3840,zoompan=z='1+0.05*on/${frames}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=1080x1920:fps=30,format=yuv420p" \
    -c:v libx264 -preset slow -crf 18 "segments/$(printf '%02d' $i).mp4"
  echo "file '$(printf '%02d' $i).mp4'" >> segments/list.txt
done

ffmpeg -y -loglevel error -f concat -safe 0 -i segments/list.txt -c:v libx264 -preset slow -crf 18 \
  -pix_fmt yuv420p -movflags +faststart reel-hyc-enchanteds.mp4
rm -rf segments
echo "wrote $(pwd)/reel-hyc-enchanteds.mp4"
