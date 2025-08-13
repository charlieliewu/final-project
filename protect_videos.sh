#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo "FFmpeg (v4.0+) Linux video protection pipeline"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ff="ffmpeg"
if ! command -v "$ff" >/dev/null 2>&1; then
  if [[ -x "$script_dir/ffmpeg" ]]; then
    ff="$script_dir/ffmpeg"
    echo "  > Using local ffmpeg"
  else
    echo "ERROR: ffmpeg not found in PATH. Please install ffmpeg (v4.0+)." >&2
    exit 1
  fi
fi

# ========== Parameters ==========
CRF=18
PRESET="slow"
GRID_ALPHA=0.012
GRID_STEP=3
GRID_THICK=1
ROT_AMP_DEG=0.2
HUE_RANGE_DEG=4
GRAIN_ALPHA=0.10
GRAIN_AMP=8

USE_LOGO=true
LOGO_PATH="./logo.png"
LOGO_SIZE=256
LOGO_ALPHA=0.015
LOGO_SPEED_X=8
LOGO_SPEED_Y=6

# ========== Folders and file discovery ==========
target_folder="$script_dir"
output_folder="$target_folder/protected_output"
mkdir -p "$output_folder"

# Find video files recursively, excluding the output folder
mapfile -d '' files < <(find "$target_folder" -type f \
  \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.flv" -o -iname "*.wmv" \) \
  -not -path "$output_folder/*" -print0)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No input videos found."
  exit 0
fi

echo "==================================================================="
echo "  ${#files[@]} files to process"
echo "==================================================================="

for file in "${files[@]}"; do
  base="$(basename "$file")"
  name="${base%.*}"
  out="$output_folder/${name}_protected.mp4"

  if [[ -e "$out" ]]; then
    echo "[skip] $base"
    continue
  fi

  echo "[process] $file"

  # Prepare filter script
  tmp=$(mktemp -t ff_filter_XXXXXX.txt)

  # Compute logo
  use_logo="false"
  if [[ "$USE_LOGO" == "true" && -f "$LOGO_PATH" ]]; then
    if logo_abs="$(readlink -f "$LOGO_PATH" 2>/dev/null)"; then
      :
    else
      logo_abs="$LOGO_PATH"
      case "$logo_abs" in
        /*) ;;
        *) logo_abs="$script_dir/$logo_abs" ;;
      esac
    fi
    # Escape single quotes for ffmpeg filter
    logo_escaped=$(printf "%s" "$logo_abs" | sed "s/'/\\\\'/g")
    use_logo="true"
  fi

  {
    echo "[0:v]format=yuv420p,split=3[b0][e0][g0];"
    echo "[b0]rotate=(PI/180)*$ROT_AMP_DEG*sin(n*0.10),hue=h=sin(n/120)*$HUE_RANGE_DEG[base];"
    echo "[e0]edgedetect=low=0.10:high=0.30,negate,boxblur=2:1,scale=1920:1080[edge];"
    echo "[g0]drawgrid=width=$GRID_STEP:height=$GRID_STEP:thickness=$GRID_THICK:color=white@${GRID_ALPHA}:,scale=1920:1080[grid];"
    echo "nullsrc=s=320x180[ns];"
    echo "[ns]geq=r='128+${GRAIN_AMP}*(random(0)-0.5)':g='128+${GRAIN_AMP}*(random(1)-0.5)':b='128+${GRAIN_AMP}*(random(2)-0.5)'[ng];"
    echo "[ng][b0]scale2ref[grain_s][ref];"
    echo "[ref]nullsink;"
    echo "[grain_s]boxblur=2:1,format=rgba,colorchannelmixer=aa=$GRAIN_ALPHA[grain];"
    echo "[base][edge]blend=all_mode=overlay:all_opacity=0.06[m1];"
    echo "[m1][grid]blend=all_mode=overlay:all_opacity=1.0[m2];"
    if [[ "$use_logo" == "true" ]]; then
      echo "movie='$logo_escaped',format=rgba,scale=${LOGO_SIZE}:-1[wm];"
      echo "[m2][wm]overlay=x='mod(t*$LOGO_SPEED_X,main_w+W)-W':y='mod(t*$LOGO_SPEED_Y,main_h+H)-H':format=auto:alpha=$LOGO_ALPHA[m3];"
      echo "[m3][grain]overlay=0:0:format=auto[vout]"
    else
      echo "[m2][grain]overlay=0:0:format=auto[vout]"
    fi
  } > "$tmp"

  # Run ffmpeg
  if "$ff" -y -i "$file" -filter_complex_script "$tmp" -map "[vout]" -map 0:a? \
      -c:v libx264 -crf "$CRF" -preset "$PRESET" -pix_fmt yuv420p \
      -g 60 -x264-params keyint=60:min-keyint=60:scenecut=0 \
      -c:a copy -movflags +faststart "$out"; then
    echo "  -> [ok] $base -> ${name}_protected.mp4"
  else
    code=$?
    echo "  -> [fail] $base FFmpeg exited with code $code" >&2
  fi

  rm -f "$tmp"
  echo "------------------------------------------------------------------"

done

echo "Done. Output: $output_folder"