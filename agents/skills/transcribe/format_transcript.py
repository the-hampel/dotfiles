#!/usr/bin/env python3
"""Turn a WhisperX diarized JSON into a readable markdown transcript.

Consecutive segments of the same speaker are merged into one paragraph,
prefixed with the speaker label and the start timestamp.
"""
import json
import sys


def ts(sec):
    sec = int(sec)
    return f'{sec // 3600:d}:{sec % 3600 // 60:02d}:{sec % 60:02d}'


def main(path):
    with open(path) as f:
        segments = json.load(f)['segments']

    blocks = []
    for seg in segments:
        speaker = seg.get('speaker', 'UNKNOWN')
        text = seg['text'].strip()
        if blocks and blocks[-1][0] == speaker:
            blocks[-1][2].append(text)
        else:
            blocks.append((speaker, seg['start'], [text]))

    for speaker, start, texts in blocks:
        print(f'**{speaker}** [{ts(start)}]: {" ".join(texts)}\n')


if __name__ == '__main__':
    main(sys.argv[1])
