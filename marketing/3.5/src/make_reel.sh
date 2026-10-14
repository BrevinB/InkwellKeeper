#!/bin/zsh
# Assembles the 3.5 storage reel from the stills make_launch_images.py renders.
#   zsh marketing/3.5/src/make_reel.sh
# Each still gets a slow push-in (rendered at 2x first so the zoom stays smooth),
# then they're cross-faded together. Silent by design: add trending audio in IG.
set -euo pipefail
cd "$(dirname "$0")/../../drafts/reels/2026-10-13"
mkdir -p segments

SECONDS_PER=3.2
FRAMES=$(( 32 * 3 ))   # 3.2s at 30fps
i=0
for still in stills/0*.png; do
  i=$(( i + 1 ))
  ffmpeg -y -loglevel error -loop 1 -i "$still" -t $SECONDS_PER \
    -vf "scale=2160:3840,zoompan=z='1+0.06*on/${FRAMES}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${FRAMES}:s=1080x1920:fps=30,format=yuv420p" \
    -c:v libx264 -preset slow -crf 18 "segments/$(printf '%02d' $i).mp4"
done

# Cross-fade the segments (0.4s overlaps).
XF=0.4
inputs=()
for f in segments/*.mp4; do inputs+=(-i "$f"); done
count=${#inputs[@]}; count=$(( count / 2 ))
filter=""
prev="0:v"
offset=$(( SECONDS_PER - XF ))
for (( n = 1; n < count; n++ )); do
  out="v$n"
  filter+="[${prev}][${n}:v]xfade=transition=fade:duration=${XF}:offset=${offset}[${out}];"
  prev=$out
  offset=$(( offset + SECONDS_PER - XF ))
done
ffmpeg -y -loglevel error "${inputs[@]}" -filter_complex "${filter%;}" -map "[$prev]" \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart reel-storage-launch.mp4
echo "wrote $(pwd)/reel-storage-launch.mp4"
