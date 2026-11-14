#!/usr/bin/env python3
"""Clue sheets -> crossword packs (JSON) for the app.

    python3 tools/generate.py --plan content/packs.json --out app/Resources/Packs \
        content/clues.csv content/drafts/*.csv [--allow-unreviewed] [--seed 7]

Rules (replica/architecture.md §2):
- rows without `reviewed_by` are skipped unless --allow-unreviewed (dev builds only)
- answers are normalised exactly like the app (ArabicText.swift); 2-8 letters
- every level is one connected grid, every crossing letter matches, max 8 wide x 9 tall
- each answer and each clue is used at most once in the whole game
- col 0 is the RIGHTMOST column; "across" words run right->left (index order)
Deterministic: same sheets + plan + seed => same packs.
"""
import argparse, csv, glob, json, os, random, re, sys

TASHKEEL = re.compile("[ً-ْٰـ]")
MAP = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ؤ": "و", "ئ": "ي"})
ALPHABET = set("ابتثجحخدذرزسشصضطظعغفقكلمنهوية" + "ء")
MAX_W, MAX_H = 8, 9
CATEGORIES = {"gulf", "geography", "general", "language", "nature", "science", "sport", "history", "religion", "food"}


def normalise(s):
    return TASHKEEL.sub("", s.strip()).translate(MAP).replace(" ", "")


# ---------- loading ----------

def load(paths, allow_unreviewed):
    rows, problems, skipped = [], [], 0
    seen_ans, seen_clue = {}, {}
    for path in paths:
        with open(path, encoding="utf-8") as f:
            for n, r in enumerate(csv.DictReader(f), start=2):
                where = "%s:%d" % (os.path.basename(path), n)
                if not (r.get("reviewed_by") or "").strip() and not allow_unreviewed:
                    skipped += 1
                    continue
                a = normalise(r.get("answer", ""))
                clue = (r.get("clue_ar") or "").strip()
                cat = (r.get("category") or "").strip()
                bad = set(a) - ALPHABET
                if bad or not 2 <= len(a) <= 8:
                    problems.append("%s answer %r: letters %s / length %d" % (where, r.get("answer"), "".join(bad), len(a)))
                    continue
                if not clue or len(clue) > 90:
                    problems.append("%s clue empty or > 90 chars" % where); continue
                if cat not in CATEGORIES:
                    problems.append("%s unknown category %r" % (where, cat)); continue
                if a in normalise(clue):
                    problems.append("%s clue contains the answer %s" % (where, a)); continue
                if a in seen_ans:
                    problems.append("%s duplicate answer %s (also %s)" % (where, a, seen_ans[a])); continue
                if clue in seen_clue:
                    problems.append("%s duplicate clue (also %s)" % (where, seen_clue[clue])); continue
                seen_ans[a] = where; seen_clue[clue] = where
                try:
                    diff = min(3, max(1, int(r.get("difficulty") or 1)))
                except ValueError:
                    diff = 1
                rows.append({"id": r["id"].strip(), "answer": a, "clue_ar": clue, "category": cat,
                             "region": (r.get("region") or "general").strip(), "difficulty": diff,
                             "image": (r.get("image") or "").strip() or None})
    ids = [r["id"] for r in rows]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        sys.exit("duplicate ids: %s" % ", ".join(sorted(dup)))
    return rows, problems, skipped


# ---------- packer ----------

def cells_of(word, r, c, d):
    return [(r + (i if d == "down" else 0), c + (i if d == "across" else 0)) for i in range(len(word))]


def can_place(grid, word, r, c, d):
    """Crossword rules: letters match on crossings, nothing touches side by side."""
    dr, dc = (1, 0) if d == "down" else (0, 1)
    if (r - dr, c - dc) in grid or (r + dr * len(word), c + dc * len(word)) in grid:
        return 0
    crossings = 0
    for i, (rr, cc) in enumerate(cells_of(word, r, c, d)):
        if (rr, cc) in grid:
            if grid[(rr, cc)][0] != word[i] or grid[(rr, cc)][1] == d:
                return 0
            crossings += 1
            continue
        if (rr + dc, cc + dr) in grid or (rr - dc, cc - dr) in grid:
            return 0
    return crossings


def bbox(cells):
    rs = [k[0] for k in cells]; cs = [k[1] for k in cells]
    return min(rs), max(rs), min(cs), max(cs)


def best_spot(grid, word, rng):
    best = None
    for (gr, gc), (ch, _) in grid.items():
        for i, wc in enumerate(word):
            if wc != ch:
                continue
            for d in ("across", "down"):
                r, c = (gr - i, gc) if d == "down" else (gr, gc - i)
                x = can_place(grid, word, r, c, d)
                if not x:
                    continue
                r0, r1, c0, c1 = bbox(list(grid) + cells_of(word, r, c, d))
                w, h = c1 - c0 + 1, r1 - r0 + 1
                if w > MAX_W or h > MAX_H:
                    continue
                score = x * 50 - w * h - abs(w - h) * 2 + rng.random()
                if best is None or score > best[0]:
                    best = (score, r, c, d)
    return best


def build_level(candidates, target, rng, tries=12):
    """Greedy pack from a weighted candidate list; best of several seeds."""
    best = None
    seeds = [w for w in candidates[:40] if 4 <= len(w["answer"]) <= 7][:tries] or candidates[:tries]
    for seed in seeds:
        grid, placed = {}, [(seed, 0, 0, "across")]
        for i, ch in enumerate(seed["answer"]):
            grid[(0, i)] = (ch, "across")
        for w in candidates:
            if len(placed) >= target:
                break
            if w is seed:
                continue
            spot = best_spot(grid, w["answer"], rng)
            if not spot:
                continue
            _, r, c, d = spot
            for k, cell in enumerate(cells_of(w["answer"], r, c, d)):
                grid[cell] = (w["answer"][k], d if cell not in grid else "both")
            placed.append((w, r, c, d))
        r0, r1, c0, c1 = bbox(grid)
        score = len(placed) * 100 - (r1 - r0 + 1) * (c1 - c0 + 1)
        if best is None or score > best[0]:
            best = (score, placed, (r0, r1, c0, c1))
        if len(placed) >= target:
            break
    return best


def weighted_order(pool, weights, rng):
    """Weighted shuffle (Efraimidis-Spirakis): heavier categories come first more often."""
    keyed = []
    for w in pool:
        wt = weights.get(w["category"], 0)
        if wt <= 0:
            continue
        keyed.append((rng.random() ** (1.0 / wt), w))
    keyed.sort(key=lambda t: -t[0])
    return [w for _, w in keyed]


def make_pack(spec, pool, rng):
    levels = []
    n = spec["levels"]
    d0, d1 = spec["diff"]
    for i in range(n):
        t = i / max(1, n - 1)
        max_diff = round(d0 + (d1 - d0) * t)
        min_diff = d0 if d1 == d0 else (2 if spec["diff"][0] >= 2 else 1)
        target = round(spec["words_min"] + (spec["words_max"] - spec["words_min"]) * t)
        cands = [w for w in pool if min_diff <= w["difficulty"] <= max_diff]
        cands = weighted_order(cands, spec["weights"], rng)
        if len(cands) < 4:
            break
        found = build_level(cands, target, rng)
        if not found or len(found[1]) < max(4, target - 2):
            break
        _, placed, (r0, r1, c0, c1) = found
        entries = []
        for w, r, c, d in placed:
            entries.append({"id": w["id"], "answer": w["answer"], "row": r - r0, "col": c - c0, "dir": d,
                            "clue_ar": w["clue_ar"], "image": w["image"], "category": w["category"],
                            "difficulty": w["difficulty"]})
        level = {"id": "%s-%03d" % (spec["id"], i + 1), "number": i + 1,
                 "width": c1 - c0 + 1, "height": r1 - r0 + 1, "entries": entries}
        validate(level)
        levels.append(level)
        used = {e["id"] for e in entries}
        pool[:] = [w for w in pool if w["id"] not in used]
    return {"id": spec["id"], "title_ar": spec["title"], "order": spec["order"],
            "region": "gulf", "levels": levels}


def validate(level):
    grid = {}
    for e in level["entries"]:
        for i, cell in enumerate(cells_of(e["answer"], e["row"], e["col"], e["dir"])):
            if cell in grid and grid[cell] != e["answer"][i]:
                raise AssertionError("crossing mismatch in %s at %s" % (level["id"], cell))
            grid[cell] = e["answer"][i]
            assert 0 <= cell[0] < level["height"] and 0 <= cell[1] < level["width"], "out of bounds"
    start = next(iter(grid)); seen = {start}; stack = [start]
    while stack:
        r, c = stack.pop()
        for nb in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
            if nb in grid and nb not in seen:
                seen.add(nb); stack.append(nb)
    assert len(seen) == len(grid), "grid not connected in %s" % level["id"]


def show(level):
    grid = {}
    for e in level["entries"]:
        for i, cell in enumerate(cells_of(e["answer"], e["row"], e["col"], e["dir"])):
            grid[cell] = e["answer"][i]
    print("\n%s  %dx%d  %s" % (level["id"], level["width"], level["height"], " ".join(e["answer"] for e in level["entries"])))
    for r in range(level["height"]):
        print(" ".join(grid.get((r, c), "·") for c in reversed(range(level["width"]))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheets", nargs="+")
    ap.add_argument("--plan", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--allow-unreviewed", action="store_true")
    ap.add_argument("--show", type=int, default=0, help="print the first N levels of each pack")
    a = ap.parse_args()
    paths = sorted({p for s in a.sheets for p in glob.glob(s)})
    rows, problems, skipped = load(paths, a.allow_unreviewed)
    for p in problems:
        print("SKIP", p)
    rng = random.Random(a.seed)
    plan = json.load(open(a.plan, encoding="utf-8"))["packs"]
    pool = rows[:]
    os.makedirs(a.out, exist_ok=True)
    for old in glob.glob(os.path.join(a.out, "*.json")):
        os.remove(old)
    total_levels = total_words = 0
    for spec in plan:
        pack = make_pack(spec, pool, rng)
        if not pack["levels"]:
            print("%s: no levels (pool exhausted)" % spec["id"])
            continue
        with open(os.path.join(a.out, spec["id"] + ".json"), "w", encoding="utf-8") as f:
            json.dump(pack, f, ensure_ascii=False, separators=(",", ":"))
        words = sum(len(l["entries"]) for l in pack["levels"])
        sizes = [len(l["entries"]) for l in pack["levels"]]
        print("%s %-14s %2d levels, %3d words (%d-%d per level)" % (spec["id"], spec["title"], len(pack["levels"]), words, min(sizes), max(sizes)))
        total_levels += len(pack["levels"]); total_words += words
        for l in pack["levels"][: a.show]:
            show(l)
    by_cat = {}
    for w in pool:
        by_cat[w["category"]] = by_cat.get(w["category"], 0) + 1
    print("\nTOTAL %d levels, %d words placed; %d clues loaded, %d unused %s; %d problems; %d skipped (unreviewed)"
          % (total_levels, total_words, len(rows), len(pool), by_cat, len(problems), skipped))


if __name__ == "__main__":
    main()
