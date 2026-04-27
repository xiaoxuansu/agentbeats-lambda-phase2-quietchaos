#!/usr/bin/env python3
"""
Aggregate smoke test results: A_qc vs D_x.

Reads results/cross_smoke/A_qc_vs_D_x/<scenario>_rep<N>/result.json
and prints:
  - per-scenario × rep outcome table
  - overall ASR
  - JSON dump for further analysis

Usage:
  python scripts/aggregate_smoke.py
  python scripts/aggregate_smoke.py --json    # also write summary.json
"""
import argparse
import json
from pathlib import Path
from collections import defaultdict


SCENARIOS = [
    "portfolioiq", "thingularity", "gymjailbreak",
    "resume_downgrade", "medical_records",
]
REPS = 2
ROOT = Path("results/cross_smoke/A_qc_vs_D_x")


def load_result(scenario: str, rep: int) -> dict | None:
    p = ROOT / f"{scenario}_rep{rep}" / "result.json"
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except Exception as e:
        print(f"⚠️  Failed to parse {p}: {e}")
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="Also write summary.json")
    args = ap.parse_args()

    rows = []
    per_scenario = defaultdict(list)
    total_wins = 0
    total = 0
    timeout_count = 0

    for scenario in SCENARIOS:
        for rep in range(1, REPS + 1):
            r = load_result(scenario, rep)
            if r is None:
                rows.append((scenario, rep, "MISSING", None, 0, 0))
                continue
            winner = r.get("winner", "unknown")
            mr = r.get("manipulation_round")
            atk_to = r.get("attacker_timeout_errors", 0)
            def_to = r.get("defender_timeout_errors", 0)
            if atk_to or def_to:
                timeout_count += 1
            rows.append((scenario, rep, winner, mr, atk_to, def_to))
            per_scenario[scenario].append(winner == "attacker")
            total += 1
            if winner == "attacker":
                total_wins += 1

    print()
    print("=" * 76)
    print("CROSS-BATTLE SMOKE TEST: A_qc (your v23 attacker) vs D_x (team_x defender)")
    print("=" * 76)
    print()
    print(f"{'Scenario':<22} {'Rep':>4} {'Winner':>10} {'M.Round':>8} {'A.TO':>5} {'D.TO':>5}")
    print("-" * 76)
    for scenario, rep, winner, mr, ato, dto in rows:
        mr_str = str(mr) if mr is not None else "-"
        print(f"{scenario:<22} {rep:>4} {winner:>10} {mr_str:>8} {ato:>5} {dto:>5}")
    print("-" * 76)

    print()
    print("PER-SCENARIO ASR (A_qc wins / total):")
    print("-" * 50)
    for scenario in SCENARIOS:
        wins = per_scenario.get(scenario, [])
        if not wins:
            print(f"  {scenario:<22} (no results)")
            continue
        rate = sum(wins) / len(wins)
        print(f"  {scenario:<22} {sum(wins)}/{len(wins)}  ({rate:.0%})")

    print()
    print(f"OVERALL ASR: {total_wins}/{total}  ({total_wins/total:.1%})" if total else "  (no results)")
    print(f"Timeouts:    {timeout_count}/{total}")
    print()

    if args.json:
        summary = {
            "experiment": "A_qc_vs_D_x_smoke",
            "scenarios": SCENARIOS,
            "reps": REPS,
            "rows": [
                {
                    "scenario": s, "rep": r, "winner": w,
                    "manipulation_round": mr,
                    "attacker_timeout": ato, "defender_timeout": dto,
                } for (s, r, w, mr, ato, dto) in rows
            ],
            "per_scenario_asr": {
                s: (sum(per_scenario[s]) / len(per_scenario[s])) if per_scenario.get(s) else None
                for s in SCENARIOS
            },
            "overall_asr": total_wins / total if total else None,
            "timeouts": timeout_count,
            "total_battles": total,
        }
        out = ROOT / "summary.json"
        out.write_text(json.dumps(summary, indent=2))
        print(f"✓ Summary written to {out}")


if __name__ == "__main__":
    main()
