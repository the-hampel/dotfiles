#!/usr/bin/env bash
# Local meeting transcription with speaker diarization (WhisperX + pyannote).
#
# usage: transcribe.sh <audio> [-n speakers] [-l lang] [-m model] [-o outdir]
#   -n  number of speakers: exact (4) or range (4-6); omit to let pyannote guess
#   -l  language code (de, en, ...); omit for auto-detect
#   -m  whisper model (default large-v3; large-v3-turbo is ~2x faster)
#   -o  output dir (default: <audio dir>/<audio basename>_transcript)
#
# Needs: whisperx (uv tool install --python 3.12 whisperx), ffmpeg, and a
# HuggingFace token (HF_TOKEN or ~/.cache/huggingface/token) whose account has
# accepted the terms of pyannote/speaker-diarization-community-1.
set -euo pipefail

usage() { sed -n '4,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

[[ $# -ge 1 ]] || usage
audio=$1; shift
[[ -f $audio ]] || { echo "no such file: $audio" >&2; exit 1; }

speakers="" lang="" model="large-v3" outdir=""
while getopts "n:l:m:o:h" opt; do
  case $opt in
    n) speakers=$OPTARG ;;
    l) lang=$OPTARG ;;
    m) model=$OPTARG ;;
    o) outdir=$OPTARG ;;
    *) usage ;;
  esac
done

token=${HF_TOKEN:-}
[[ -z $token && -f ~/.cache/huggingface/token ]] && token=$(<~/.cache/huggingface/token)
[[ -n $token ]] || { echo "no HuggingFace token: set HF_TOKEN or run 'uvx hf auth login'" >&2; exit 1; }

base=$(basename "${audio%.*}")
[[ -n $outdir ]] || outdir="$(cd "$(dirname "$audio")" && pwd)/${base}_transcript"
mkdir -p "$outdir"

args=(--model "$model" --compute_type int8 --device cpu --threads "$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo 8)"
      --diarize --hf_token "$token" --output_format all --output_dir "$outdir")
[[ -n $lang ]] && args+=(--language "$lang")
[[ -n $speakers ]] && args+=(--min_speakers "${speakers%-*}" --max_speakers "${speakers#*-}")

echo "transcribing $audio -> $outdir (model=$model lang=${lang:-auto} speakers=${speakers:-auto})" >&2
time whisperx "$audio" "${args[@]}"

python3 "$(dirname "$0")/format_transcript.py" "$outdir/$base.json" > "$outdir/$base.md"
echo "readable transcript: $outdir/$base.md" >&2
