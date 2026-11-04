"""Score tables and the pass rule for one judging round.

    python docs/judging/scores.py docs/judging/round-N

Reads `letters.json` and `responses/<judge>-<group>.md` (each ending in
the JSON block the prompt asks for) and prints, per judge and pair,
xlkit's and the other library's design and docs totals over their common
tasks, xlkit's lowest common task scores, and whether the pair passes.
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bundle import GROUPS, support  # noqa: E402

JUDGES = ("sonnet", "terra")


def scores(path):
    text = open(path, encoding="utf-8").read()
    blocks = re.findall(r"```json\s*(\{.*?\})\s*```", text, re.S)
    return json.loads(blocks[-1])


def design(s):
    return sum(s[:2]) / 2


def docs(s):
    return sum(s[2:6]) / 4


def main(round_dir):
    letters = json.load(open(os.path.join(round_dir, "letters.json")))["groups"]
    common = support()
    passed = True
    print("| judge | other library | xlkit design | other design | xlkit docs | other docs | xlkit lowest (design, docs) | pass |")
    print("|---|---|---|---|---|---|---|---|")
    for judge in JUDGES:
        for group, others in GROUPS.items():
            path = os.path.join(round_dir, "responses", f"{judge}-{group.lower()}.md")
            if not os.path.exists(path):
                print(f"| {judge} | {group}: missing response | | | | | | no |")
                passed = False
                continue
            s = scores(path)
            ours = s[letters[group]["xlkit"]]
            for other in others or ["Stata"]:
                theirs = s["Stata"] if other == "Stata" else s[letters[group][other]]
                tasks = [str(t) for t in common[other]]
                od, td = sum(design(ours[t]) for t in tasks), sum(design(theirs[t]) for t in tasks)
                low_design = min(design(ours[t]) for t in tasks)
                if other == "Stata":
                    ok = od > td and low_design >= 2
                    print(f"| {judge} | Stata | {od:.2f} | {td:.2f} | | | {low_design:.2f} | {'yes' if ok else 'no'} |")
                else:
                    oc, tc = sum(docs(ours[t]) for t in tasks), sum(docs(theirs[t]) for t in tasks)
                    low_docs = min(docs(ours[t]) for t in tasks)
                    ok = od > td and oc > tc and low_design >= 2 and low_docs >= 2
                    print(f"| {judge} | {other} | {od:.2f} | {td:.2f} | {oc:.2f} | {tc:.2f} "
                          f"| {low_design:.2f}, {low_docs:.2f} | {'yes' if ok else 'no'} |")
                passed &= ok
    print(f"\nRound {'passes' if passed else 'fails'}.")


if __name__ == "__main__":
    main(sys.argv[1])
