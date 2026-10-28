---
name: transcribe
description: Transcribe a local meeting/audio recording (e.g. iPhone Voice Memo .m4a) fully offline with WhisperX, label who spoke when (speaker diarization), map speakers to real names, then produce a cleaned transcript with rambling/filler removed plus a summary with decisions and action items. Use when the user hands over an audio file to transcribe, mentions a meeting recording, voice memo, "transcribe", "who said what", or wants meeting notes/minutes from audio. Arguments: audio path, optionally number of speakers, speaker names, language.
---

# Meeting transcription (local, WhisperX + pyannote)

Everything runs locally on the Mac. Scripts live next to this file:
- `transcribe.sh <audio> [-n speakers] [-l lang] [-m model] [-o outdir]`: runs WhisperX with diarization and writes
  `<outdir>/<base>.{json,srt,vtt,txt,tsv}` plus a readable `<base>.md` (merged speaker turns with timestamps).
  Default outdir: `<audio dir>/<base>_transcript/`.
- `format_transcript.py <json>`: rebuilds `<base>.md` from the JSON (used by the script).

## Steps

1. **Parse the request.** Get the audio path, speaker count (`-n 4`, or a range `-n 4-6` when visitors
   dropped in so they get their own label instead of being merged into a main speaker), speaker names if given, and the language
   (`-l de` / `-l en`; give it whenever it's known, since auto-detect from the first 30 s can be wrong). iPhone
   Voice Memos are `.m4a`; ffmpeg handles them as-is. If the path is vague, look in `~/Downloads`
   and the iCloud Voice Memos/Desktop folders.
2. **Run** `transcribe.sh` with `run_in_background: true`. It is slow: large-v3 on CPU int8 took 52 min for a
   55 min recording on the M3 Max (≈30 min transcription, ≈20 min diarization). Use `-m large-v3-turbo` if the user wants it faster.
   The first run downloads the models (~3 GB).
3. **Name the speakers.** Read `<base>.md`. Infer which `SPEAKER_xx` is whom from context: people addressing
   each other by name, self-introductions, who chairs the meeting, and the names the user gave. Show the user
   the proposed mapping with one short sample line per speaker and get confirmation **before** rewriting anything.
   If the user gave fewer speakers than pyannote found (or more), say so; small spurious speakers
   with a handful of lines are usually misattributions and can be merged.
4. **Write the outputs** into the transcript dir (keep the raw files untouched):
   - `<base>_named.md`: verbatim transcript with names substituted.
   - `<base>_clean.md`: same structure (speaker + timestamp per turn) but with rambling removed: drop fillers,
     false starts, repetitions, self-corrections, crosstalk fragments and off-topic small talk; merge broken sentences;
     fix obvious mis-transcriptions of technical terms. **Never change meaning, never invent content, never drop a
     decision, number, date, name or commitment.** Keep the meeting's language. Mark omitted off-topic stretches as
     `[… small talk omitted, 0:12:30–0:15:10]`.
   - `<base>_summary.md`: date/participants, 5–10 bullet summary, decisions, action items (who / what / when),
     open questions.
   For long meetings, process the transcript in chunks so nothing in the middle gets skimmed.
5. **Report** concisely: paths of the files, duration, speaker mapping, and anything uncertain (inaudible parts,
   low-confidence speaker assignment).

## Setup / troubleshooting

- Install: `brew install ffmpeg uv && uv tool install --python 3.12 whisperx` (Python 3.14 is too new for torch).
- HF token: needed once to download the gated pyannote model. Run `uvx hf auth login` (stores it in
  `~/.cache/huggingface/token`) or set `HF_TOKEN`, **and** accept the terms on
  https://huggingface.co/pyannote/speaker-diarization-community-1 with that account. A 401/403 or a "gated repo"
  error means the terms were not accepted.
- Diarization quality: an exact `-n` helps a lot. Overlapping speech and similar voices are the usual failure;
  the transcript text stays fine, only the labels flip.
- Runs on CPU. faster-whisper (CTranslate2) has no Apple GPU (MPS) backend; that is expected.
