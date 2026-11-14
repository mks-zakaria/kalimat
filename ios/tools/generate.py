#!/usr/bin/env python3
"""Clue sheet -> crossword packs (JSON) for the app.

    python3 tools/generate.py content/clues.csv app/Resources/Packs --pack gulf-1 --title "الخليج ١" --per-level 6
    python3 tools/generate.py ... --allow-unreviewed      # local dev only; never for a release build

Rules (replica/architecture.md §2):
- rows without `reviewed_by` are skipped unless --allow-unreviewed
- answers are normalised exactly like the app (ArabicText.swift) and must be 2-9 letters
- every level is one connected grid, every crossing letter matches, max 9x9
- col 0 is the RIGHTMOST column; "across" words run right->left (index order)
Deterministic: same sheet + same --seed => same packs.
"""
import argparse, csv, json, os, random, re, sys

TASHKEEL = re.compile("[ً-ْٰـ]")
MAP = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ؤ": "و", "ئ": "ي"})
ALPHABET = set("ابتثجحخدذرزسشصضطظعغفقكلمنهوية" + "ء")
MAX_SIDE = 9


def normalise(s):
    s = TASHKEEL.sub("", s.strip()).translate(MAP).replace(" ", "")
    return s


def load(path, allow_unreviewed):
    rows, skipped = [], 0
    with open(path, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if not r["reviewed_by"].strip() and not allow_unreviewed:
                skipped += 1
                continue
            a = normalise(r["answer"])
            bad = set(a) - ALPHABET
            if bad or not 2 <= len(a) <= MAX_SIDE:
                sys.exit("bad answer %s %r (letters %s)" % (r["id"], r["answer"], bad))
            rows.append({**r, "answer": a})
    ids = [r["id"] for r in rows]
    if len(ids) != len(set(ids)):
        sys.exit("duplicate ids")
    clues = [r["clue_ar"].strip() for r in rows]
    if len(clues) != len(set(clues)):
        sys.exit("duplicate clue text")
    return rows, skipped


# ---------- packer ----------

def cells_of(word, r, c, d):
    return [(r + (i if d == "down" else 0), c + (i if d == "across" else 0)) for i in range(len(word))]


def can_place(grid, word, r, c, d):
    """Standard crossword rules: letters match on crossings, no touching side by side."""
    dr, dc = (1, 0) if d == "down" else (0, 1)
    before = (r - dr, c - dc)
    after = (r + dr * len(word), c + dc * len(word))
    if before in grid or after in grid:
        return False, 0
    crossings = 0
    for i, (rr, cc) in enumerate(cells_of(word, r, c, d)):
        if (rr, cc) in grid:
            if grid[(rr, cc)] != word[i]:
                return False, 0
            crossings += 1
            continue
        # a new letter must not touch other letters sideways
        side = [(rr + dc, cc + dr), (rr - dc, cc - dr)]
        if any(s in grid for s in side):
            return False, 0
    return crossings > 0, crossings


def bbox(grid):
    rs = [k[0] for k in grid]; cs = [k[1] for k in grid]
    return min(rs), max(rs), min(cs), max(cs)


def try_pack(words, rng, tries=200):
    best = None
    for _ in range(tries):
        order = words[:]
        rng.shuffle(order)
        order.sort(key=lambda w: -len(w["answer"]))  # long first, shuffled ties
        grid, placed = {}, []
        first = order[0]
        for (rr, cc) in cells_of(first["answer"], 0, 0, "across"):
            pass
        for i, ch in enumerate(first["answer"]):
            grid[(0, i)] = ch
        placed.append((first, 0, 0, "across"))
        for w in order[1:]:
            cands = []
            for (gr, gc), ch in list(grid.items()):
                for i, wc in enumerate(w["answer"]):
                    if wc != ch:
                        continue
                    for d in ("across", "down"):
                        r, c = (gr - i, gc) if d == "down" else (gr, gc - i)
                        ok, x = can_place(grid, w["answer"], r, c, d)
                        if not ok:
                            continue
                        trial = dict(grid)
                        for k, (rr, cc) in enumerate(cells_of(w["answer"], r, c, d)):
                            trial[(rr, cc)] = w["answer"][k]
                        r0, r1, c0, c1 = bbox(trial)
                        if r1 - r0 + 1 > MAX_SIDE or c1 - c0 + 1 > MAX_SIDE:
                            continue
                        area = (r1 - r0 + 1) * (c1 - c0 + 1)
                        cands.append((x * 100 - area + rng.random(), r, c, d))
            if not cands:
                continue
            _, r, c, d = max(cands)
            for k, (rr, cc) in enumerate(cells_of(w["answer"], r, c, d)):
                grid[(rr, cc)] = w["answer"][k]
            placed.append((w, r, c, d))
        r0, r1, c0, c1 = bbox(grid)
        score = len(placed) * 1000 - (r1 - r0 + 1) * (c1 - c0 + 1)
        if best is None or score > best[0]:
            best = (score, placed, (r0, r1, c0, c1))
        if len(placed) == len(words):
            pass
    return best


def build_level(words, rng, level_id, number):
    _, placed, (r0, r1, c0, c1) = try_pack(words, rng)
    entries = []
    for w, r, c, d in placed:
        entries.append({"id": w["id"], "answer": w["answer"], "row": r - r0, "col": c - c0, "dir": d,
                        "clue_ar": w["clue_ar"].strip(), "image": w["image"] or None,
                        "category": w["category"], "difficulty": int(w["difficulty"] or 1)})
    used = {e["id"] for e in entries}
    return {"id": level_id, "number": number, "width": c1 - c0 + 1, "height": r1 - r0 + 1,
            "entries": entries}, used


def validate(level):
    grid = {}
    for e in level["entries"]:
        for i, cell in enumerate(cells_of(e["answer"], e["row"], e["col"], e["dir"])):
            if cell in grid and grid[cell] != e["answer"][i]:
                raise AssertionError("crossing mismatch in %s at %s" % (level["id"], cell))
            grid[cell] = e["answer"][i]
            assert 0 <= cell[0] < level["height"] and 0 <= cell[1] < level["width"], "out of bounds"
    # connected?
    start = next(iter(grid)); seen = {start}; stack = [start]
    while stack:
        r, c = stack.pop()
        for n in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
            if n in grid and n not in seen:
                seen.add(n); stack.append(n)
    assert len(seen) == len(grid), "grid not connected in %s" % level["id"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet"); ap.add_argument("outdir")
    ap.add_argument("--pack", required=True); ap.add_argument("--title", required=True)
    ap.add_argument("--region", default="gulf"); ap.add_argument("--order", type=int, default=1)
    ap.add_argument("--per-level", type=int, default=6); ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--allow-unreviewed", action="store_true")
    a = ap.parse_args()
    rng = random.Random(a.seed)
    rows, skipped = load(a.sheet, a.allow_unreviewed)
    pool = rows[:]
    levels, n = [], 1
    while len(pool) >= 3:
        chunk = pool[: a.per_level]
        level, used = build_level(chunk, rng, "%s-%03d" % (a.pack, n), n)
        if len(used) < 3:
            break
        validate(level)
        levels.append(level)
        pool = [w for w in pool if w["id"] not in used]
        n += 1
    os.makedirs(a.outdir, exist_ok=True)
    out = {"id": a.pack, "title_ar": a.title, "order": a.order, "region": a.region, "levels": levels}
    path = os.path.join(a.outdir, a.pack + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("%s: %d levels, %d words placed, %d unplaced, %d skipped (unreviewed)"
          % (path, len(levels), sum(len(l["entries"]) for l in levels), len(pool), skipped))
    for l in levels:
        print_level(l)


def print_level(l):
    grid = {}
    for e in l["entries"]:
        for i, cell in enumerate(cells_of(e["answer"], e["row"], e["col"], e["dir"])):
            grid[cell] = e["answer"][i]
    print("\n%s  %dx%d  %s" % (l["id"], l["width"], l["height"], " ".join(e["answer"] for e in l["entries"])))
    for r in range(l["height"]):
        # print right-to-left so the terminal shows it like the app (col 0 on the right)
        print(" ".join(grid.get((r, c), "·") for c in reversed(range(l["width"]))))


if __name__ == "__main__":
    main()
