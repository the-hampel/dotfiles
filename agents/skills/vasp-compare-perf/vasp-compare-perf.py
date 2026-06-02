#!/usr/bin/env python3
"""Compare the 'Flat profile' sections of two VASP OUTCAR files."""

import re
import sys
from pathlib import Path


def parse_flatprofile(outcar_path: Path) -> dict[str, tuple[float, int]]:
    """Parse the Flat profile section of an OUTCAR file."""
    text = outcar_path.read_text()

    flat_start = text.find("Flat profile")
    accum_start = text.find("Accumulative profile")
    if flat_start == -1 or accum_start == -1:
        raise ValueError(f"Could not find profile sections in {outcar_path}")

    section = text[flat_start:accum_start]

    pattern = re.compile(r'^\s+(\S+)\s+([\d.]+)\s+(\d+)\s*$', re.MULTILINE)

    timings = {}
    for name, cpu, calls in pattern.findall(section):
        timings[name] = (float(cpu), int(calls))

    return timings


def get_final_iteration(outcar_path: Path) -> int:
    """Extract the final iteration number from an OUTCAR file.

    Looks for lines like 'Iteration      1(  15)' and returns the
    number inside the parentheses (the final one found).
    """
    text = outcar_path.read_text()

    # Match patterns like: Iteration      1(  15)
    # The number in parentheses is the iteration index
    pattern = re.compile(r'Iteration\s+\d+\(\s*(\d+)\s*\)')
    matches = pattern.findall(text)

    if not matches:
        return 0

    return int(matches[-1])


def get_final_energy(outcar_path: Path) -> float:
    """Extract the final free energy (TOTEN) from an OUTCAR file.

    Looks for lines like 'free  energy   TOTEN  =    xxx.xxx eV'.
    """
    text = outcar_path.read_text()

    pattern = re.compile(r'free\s+energy\s+TOTEN\s*=\s*([\d.eE+-]+)\s+eV')
    matches = pattern.findall(text)

    if not matches:
        return 0.0

    return float(matches[-1])


def format_table(
    timings1: dict[str, tuple[float, int]],
    timings2: dict[str, tuple[float, int]],
    outcar1_path: Path,
    outcar2_path: Path,
) -> str:
    """Build a side-by-side comparison table sorted by |diff| descending."""
    all_routines = set(timings1) | set(timings2)

    rows = []
    for name in all_routines:
        t1 = timings1.get(name)
        t2 = timings2.get(name)
        cpu1 = t1[0] if t1 else 0.0
        cpu2 = t2[0] if t2 else 0.0
        c1 = t1[1] if t1 else 0
        c2 = t2[1] if t2 else 0
        diff = cpu1 - cpu2
        abs_diff = abs(diff)
        rows.append((name, cpu1, cpu2, diff, c1, c2, abs_diff))

    rows.sort(key=lambda r: r[6], reverse=True)
    rows = rows[:50]

    total1 = sum(t[0] for t in timings1.values())
    total2 = sum(t[0] for t in timings2.values())

    name_w = max(len("Routine"), max(len(r[0]) for r in rows))
    name_w = max(name_w, 10)

    def truncate(name, width):
        if len(name) > width:
            return name[:width - 3] + '...'
        return name

    lines = []

    # Header matching data format exactly
    header = (
        f"  {'Routine':<{name_w}}  "
        f"{outcar1_path.name:>13s}  "
        f"{outcar2_path.name:>13s}  "
        f"{'diff (s)':>13s}  "
        f"{'%diff':>8s}  "
    )
    lines.append(header.rstrip())

    # Totals on top
    lines.append(f"  {'TOTAL':<{name_w}}  "
                 f"{total1:>13.4f}  "
                 f"{total2:>13.4f}  "
                 f"{total1 - total2:>13.4f}  "
                 f"{((total1 - total2) / total2 * 100):>+7.1f}%  "
                 )

    lines.append("")

    header_details = (
        f"  {'Routine':<{name_w}}  "
        f"{outcar1_path.name:>13s}  "
        f"{outcar2_path.name:>13s}  "
        f"{'diff (s)':>13s}  "
        f"{'%diff':>8s}  "
        f"{'Δcalls':>10s}\n"
    )
    lines.append(header_details.rstrip().replace(' ', '-'))

    for name, cpu1, cpu2, diff, c1, c2, _ in rows:
        name_display = truncate(name, name_w)

        if c2 > 0:
            pct_diff = (diff / cpu2) * 100 if cpu2 != 0 else float('inf') if diff > 0 else 0.0
        elif c1 > 0:
            pct_diff = float('inf') if diff > 0 else 0.0
        else:
            pct_diff = 0.0

        if abs(pct_diff) == float('inf'):
            pct_str = "---"
        else:
            pct_str = f"{pct_diff:+.1f}%"

        diff_str = f"{diff:>+13.4f}"
        c_diff = c1 - c2

        row = (
            f"  {name_display:<{name_w}}  "
            f"{cpu1:>13.4f}  "
            f"{cpu2:>13.4f}  "
            f"{diff_str:>13s}  "
            f"{pct_str:>8s}  "
            f"{c_diff:>+10d}\n"
        )
        lines.append(row.rstrip())

    lines.append("")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 3:
        print("Usage: compare_outcar.py <OUTCAR1> <OUTCAR2>")
        print("  Compares the 'Flat profile' sections of two VASP OUTCAR files.")
        print("  Routines sorted by |time difference|, largest first.")
        print("  Shows top 50 routines with totals at the top.")
        sys.exit(1)

    path1 = Path(sys.argv[1])
    path2 = Path(sys.argv[2])

    if not path1.exists():
        print(f"Error: {path1} not found")
        sys.exit(1)
    if not path2.exists():
        print(f"Error: {path2} not found")
        sys.exit(1)

    timings1 = parse_flatprofile(path1)
    timings2 = parse_flatprofile(path2)

    iter1 = get_final_iteration(path1)
    iter2 = get_final_iteration(path2)

    energy1 = get_final_energy(path1)
    energy2 = get_final_energy(path2)
    energy_diff = abs(energy1 - energy2) * 1000  # convert to meV

    if iter1 != iter2:
        print(f"\nWARNING: The two OUTCAR files have different iteration counts:")
        print(f"  {path1}: {iter1} iterations")
        print(f"  {path2}: {iter2} iterations")
        print(f"  The comparison below may be misleading.\n")

    if energy_diff > 10.0:
        print(f"\nWARNING: The final energies differ by more than 10 meV:")
        print(f"  {path1}: {energy1:.8f} eV")
        print(f"  {path2}: {energy2:.8f} eV")
        print(f"  Difference: {energy_diff:.3f} meV")
        print(f"  The comparison below may be misleading.\n")

    print(f"\n{'=' * 100}")
    print(f"  VASP Flat Profile Comparison")
    print(f"{'=' * 100}\n")
    print(format_table(timings1, timings2, path1, path2))
    print()


if __name__ == "__main__":
    main()
