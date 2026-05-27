---
name: vasp-compare-perf
description: Compare the 'Flat profile' CPU timings and call counts between two VASP OUTCAR files. Outputs a side-by-side table sorted by largest time difference. Use when the user wants to compare VASP OUTCAR profiling data or mentions comparing OUTCAR files.
---

# VASP OUTCAR Flat Profile Comparison

Compare the "Flat profile" sections of two VASP OUTCAR files and output a formatted table sorted by the biggest time difference.

## Usage

Invoke from chat by telling me to compare two OUTCAR files. I will:

1. Locate or resolve the two OUTCAR file paths the user mentions.
2. Run `python3 <skill_dir>/vasp-compare-perf.py <OUTCAR1> <OUTCAR2>`.
3. Summarize the key findings: which routines dominate the time difference, and the overall relative difference.

## What it does

- Parses the "Flat profile" section from each OUTCAR (CPU time per routine and call counts).
- Produces a side-by-side table with columns: Routine, OUTCAR1 time, OUTCAR2 time, diff (s), % diff (relative to OUTCAR2), OUTCAR1 calls, OUTCAR2 calls.
- Sorted by |time difference| descending, largest first.
- Computes totals and overall relative difference.

## Output format

```
====================================================================================================
  VASP Flat Profile Comparison
====================================================================================================

  Routine                   OUTCAR1             OUTCAR2             diff (s)      % diff   OUTCAR1     OUTCAR2
--  --------------  ----------------  ----------------  ----------------  --------  ----------  ----------
  wzgemm                    205.881498       54.902253    +150.979245   +275.0%        9702        5730
  ...

  TOTAL                         3.921983         2.965823
  Total time difference: +0.956160 s
  Relative difference: +32.24%
```

## Files

- Script: `<skill_dir>/vasp-compare-perf.py`
- Requires: Python 3, no external dependencies.
