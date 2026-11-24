"""Cuts recorded Kalimat gameplay (tools/promo/record.sh) into short vertical videos for TikTok / Reels / Shorts.

    python3 tools/promo/make_videos.py <recording dir> [--only challenge|speedrun|ws] [--limit N]
    -> <recording dir>/videos/*.mp4  +  <recording dir>/videos/manifest.csv (one row per video: format,
       hook, level, clue, answer, caption) for posting and for comparing which hooks work.

Formats (what the research on game ads says works: real gameplay, a hook in the first second, one idea per
video, a question the viewer answers in the comments):
  challenge  one crossword clue: hook + 5 s countdown over the real board, then the real solve, then the answer
  ws         one word-search word: same, the viewer hunts the word in the real grid
  speedrun   a whole level solved fast, ending on the "ممتاز!" card with the IQ score
Every video ends with a 2.5 s card: icon, name, "free on the App Store". Silent AAC track (add a platform
sound at upload). All claims match the App Store listing.
"""
import csv, json, math, subprocess, sys, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[2]                 # kalimat-ios
APP = ROOT / "app"
ICON = APP / "icon/AppIcon.png"
FONT = "/System/Library/Fonts/SFArabic.ttf"
W, H, FPS = 1080, 1920, 30
# The recording is 1206x2622; this window drops the status bar and header and keeps grid, clue and keys.
CROP = (0, 330, 1206, 2144)
GOLD, CREAM, INK, RED = (240, 190, 70), (255, 248, 232), (40, 28, 16), (176, 40, 52)
NAME = "كلمات متقاطعة: ألغاز وذكاء"

PACK_HOOK = {
    "p01": "سؤال سهل... ولا؟", "p02": "سؤال لأهل الخليج", "p03": "سؤال جغرافيا",
    "p04": "سؤال من الطبيعة", "p05": "سؤال في اللغة العربية", "p06": "سؤال رياضة وتاريخ",
    "p07": "سؤال ثقافة عامة", "p08": "سؤال للخبراء فقط",
}
CAT_HOOK = {"gulf": "سؤال لأهل الخليج", "geography": "سؤال جغرافيا", "general": "سؤال ثقافة عامة",
            "language": "سؤال في اللغة العربية", "religion": "سؤال ديني", "nature": "سؤال من الطبيعة",
            "science": "سؤال علوم", "history": "سؤال تاريخ", "food": "سؤال عن الأكل", "sport": "سؤال رياضة"}
CAT_TAGS = {"gulf": "#الخليج #السعودية #الكويت #الإمارات", "geography": "#جغرافيا #دول #عواصم", "general": "#معلومات_عامة",
            "language": "#اللغة_العربية #أمثال", "religion": "#إسلاميات #معلومات_دينية", "nature": "#طبيعة #حيوانات",
            "science": "#علوم #معلومة", "history": "#تاريخ", "food": "#أكلات #مطبخ", "sport": "#رياضة #كرة_القدم"}
CATEGORY = {}      # entry id -> category, filled from the packs

def hook_for(c):
    if c["level"].startswith("p08"): return "سؤال للخبراء فقط"
    return CAT_HOOK.get(CATEGORY.get(c["entry"], ""), "تقدر تحلها؟")

LINE2 = ["تقدر تحلها في ٥ ثواني؟", "جاوب قبل ما يخلص الوقت", "اكتب الجواب في التعليقات"]
TAGS = {"p02": "#الخليج #السعودية #الكويت", "p03": "#جغرافيا #معلومات", "p05": "#اللغة_العربية #أمثال",
        "p06": "#تاريخ #رياضة", "p07": "#ثقافة_عامة #أكلات", "p08": "#تحدي_الخبراء", "p01": "#معلومات_عامة",
        "p04": "#طبيعة #معلومات"}
AR_DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")

_fc = {}
MIXED = "/System/Library/Fonts/Supplemental/Tahoma Bold.ttf"     # SF Arabic has no Latin letters
def font(size, bold=True, mixed=False):
    k = (size, bold, mixed)
    if k not in _fc:
        f = ImageFont.truetype(MIXED if mixed else FONT, size, layout_engine=ImageFont.Layout.RAQM)
        try: f.set_variation_by_name("Bold" if bold else "Regular")
        except Exception: pass
        _fc[k] = f
    return _fc[k]

def text_w(d, s, f): return d.textlength(s, font=f, direction="rtl")
def latin(s): return any(c.isascii() and c.isalpha() for c in s)

def label(img, s, y, size, fg=INK, bg=CREAM, pad=0.38, maxw=W * 0.9):
    """Centred rounded label (creator-style caption). Returns bottom y."""
    d = ImageDraw.Draw(img)
    mx = latin(s)
    while text_w(d, s, font(size, mixed=mx)) > maxw and size > 30: size = int(size * 0.94)
    f = font(size, mixed=mx); w = text_w(d, s, f); a, de = f.getmetrics(); h = a + de
    px, py = int(size * pad), int(size * 0.18)
    x0 = (W - w) / 2 - px
    d.rounded_rectangle([x0, y, x0 + w + 2 * px, y + h + 2 * py], radius=int(size * 0.3), fill=bg)
    d.text(((W - w) / 2, y + py), s, font=f, fill=fg, direction="rtl")
    return y + h + 2 * py

def big(img, s, cy, size, fill=GOLD, stroke=INK):
    d = ImageDraw.Draw(img); f = font(size); w = text_w(d, s, f); a, de = f.getmetrics()
    d.text(((W - w) / 2, cy - (a + de) / 2), s, font=f, fill=fill, direction="rtl", stroke_width=max(2, size // 22), stroke_fill=stroke)

# ---------------------------------------------------------------- footage
VF = f"crop={CROP[2]}:{CROP[3] - CROP[1]}:{CROP[0]}:{CROP[1]},scale={W}:{H}"

def cfr_proxy(src):
    """The simulator records a variable frame rate (no frames while the screen is still); seeking into that
    with a fps filter squeezes the still moments and clips drift by seconds. Cut from a constant-30-fps,
    already-cropped copy instead (made once per recording)."""
    out = src.with_name(src.stem + ".cfr.mp4")
    if not out.exists() or out.stat().st_mtime < src.stat().st_mtime:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-vf", f"{VF},fps={FPS}", "-c:v", "libx264",
                        "-preset", "veryfast", "-crf", "16", "-g", str(FPS), "-an", str(out)], check=True)
    return out
def frames(src, t0, t1, speed=1.0):
    """Yields 1080x1920 RGB frames of [t0, t1] of the recording, played `speed` times faster."""
    vf = f"setpts=PTS/{speed},fps={FPS}"
    p = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-ss", f"{max(0, t0):.3f}", "-to", f"{t1:.3f}", "-i", str(src),
                          "-vf", vf, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    n = W * H * 3
    while True:
        b = p.stdout.read(n)
        if len(b) < n: break
        yield Image.frombytes("RGB", (W, H), b)
    p.wait()

def still(src, t):
    b = subprocess.run(["ffmpeg", "-loglevel", "error", "-ss", f"{max(0, t):.3f}", "-i", str(src), "-frames:v", "1",
                        "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    return Image.frombytes("RGB", (W, H), b[:W * H * 3])

def dim_top(img, frac=0.46, alpha=170):
    """Darkens the top part of the frame (over the grid) so the hook and countdown read clearly."""
    o = Image.new("L", (W, H), 0); d = ImageDraw.Draw(o)
    edge = int(H * frac)
    for y in range(edge + 80):
        a = alpha if y < edge else int(alpha * (1 - (y - edge) / 80))
        d.line([(0, y), (W, y)], fill=a)
    img = img.copy(); img.paste((14, 10, 6), (0, 0), o); return img

def dim_bottom(img, frac=0.52, alpha=175):
    return dim_top(img.transpose(Image.FLIP_TOP_BOTTOM), 1 - frac, alpha).transpose(Image.FLIP_TOP_BOTTOM)

_end = {}
def end_card(bg_src, t):
    if "img" not in _end:
        bg = still(bg_src, t).filter(ImageFilter.GaussianBlur(28))
        bg = Image.blend(bg, Image.new("RGB", (W, H), (30, 20, 10)), 0.45)
        ic = Image.open(ICON).convert("RGBA").resize((330, 330), Image.LANCZOS)
        m = Image.new("L", ic.size, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, 329, 329], radius=74, fill=255); ic.putalpha(m)
        bg.paste(ic, ((W - 330) // 2, 470), ic)
        y = label(bg, NAME, 860, 66)
        y = label(bg, "مجانية على App Store", y + 40, 56, fg=CREAM, bg=RED)
        label(bg, "٢٥٠ لغزًا، وتعمل بدون نت", y + 40, 44)
        _end["img"] = bg
    return _end["img"]

# ---------------------------------------------------------------- writer
class Writer:
    def __init__(self, out):
        self.p = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                                   "-r", str(FPS), "-i", "-", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo", "-shortest",
                                   "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                                   "-c:a", "aac", "-b:a", "64k", str(out)], stdin=subprocess.PIPE)
        self.n = 0
    def put(self, img, times=1):
        b = img.convert("RGB").tobytes()
        for _ in range(times): self.p.stdin.write(b); self.n += 1
    def close(self): self.p.stdin.close(); self.p.wait()

def finish(w, src, t):
    end = end_card(src, t)
    for i in range(int(2.5 * FPS)): w.put(end)
    w.close()

# ---------------------------------------------------------------- formats
def challenge(src, c, out, line2):
    """c: dict(level, clue_t, type_t, solved_t, answer, clue)."""
    hook = hook_for(c)
    base = still(src, c["clue_t"] + 0.8)
    w = Writer(out)
    for i in range(5 * FPS):                                  # countdown 5..1, hook visible from frame 0
        f = dim_top(base)
        y = label(f, hook, 150, 78)
        label(f, line2, y + 24, 56, fg=CREAM, bg=RED)
        n = 5 - i // FPS; pulse = 1 + 0.12 * max(0, 1 - (i % FPS) / 8)
        big(f, str(n).translate(AR_DIGITS), 640, int(220 * pulse))
        w.put(f)
    sp = max(1.0, (c["solved_t"] - c["type_t"]) / 2.4)        # the real solve, sped up to ~2.4 s
    for f in frames(src, c["type_t"], c["solved_t"] + 0.1, sp): w.put(f)
    # Freeze on the completed word: the game moves to the next clue within a second of solving.
    done = dim_top(still(src, c["solved_t"] + 0.1), alpha=120)
    label(done, "الجواب: " + c["answer"], 330, 92, fg=INK, bg=GOLD)
    w.put(done, int(1.6 * FPS))
    finish(w, src, c["clue_t"])

def ws_challenge(src, c, out, line2):
    base = still(src, c["clue_t"] + 0.6)
    w = Writer(out)
    for i in range(5 * FPS):
        f = dim_bottom(base)
        y = label(f, "دوّر على الكلمة", 1080, 76)
        y = label(f, c["clue"], y + 22, 54)
        label(f, line2, y + 22, 50, fg=CREAM, bg=RED)
        n = 5 - i // FPS
        big(f, str(n).translate(AR_DIGITS), 1660, 170)
        w.put(f)
    for f in frames(src, c["clue_t"] + 1.8, c["solved_t"] + 0.9): w.put(f)
    done = dim_bottom(still(src, c["solved_t"] + 0.8), alpha=120)
    label(done, "الجواب: " + c["answer"], 1250, 92, fg=INK, bg=GOLD)
    w.put(done, int(1.4 * FPS))
    finish(w, src, c["clue_t"])

def speedrun(src, lv, out, ws=False):
    pack = lv["level"][:3]
    hook = ("كلمات مخفية: " if ws else "لغز كامل: ") + PACK_TITLE.get(pack, "")
    dur = lv["complete_t"] - lv["start_t"]
    sp = max(1.0, dur / 16)
    w = Writer(out); k = 0
    for f in frames(src, lv["start_t"], lv["complete_t"], sp):
        if k < 3 * FPS:                                       # hook for the first 3 s
            label(f, hook, 60 if not ws else 1540, 64)
            label(f, "كم تاخذ أنت؟ (الفيديو مسرّع)", (60 if not ws else 1540) + 110, 44, fg=CREAM, bg=RED)
        w.put(f); k += 1
    for f in frames(src, lv["complete_t"], lv["complete_t"] + 3.5): w.put(f)   # "ممتاز!" + IQ, real speed
    finish(w, src, lv["start_t"] + 1)

PACK_TITLE = {}

# ---------------------------------------------------------------- events
# ---------------------------------------------------------------- event-driven recordings (segments.tsv)
def duration(f):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(f)],
                                capture_output=True, text=True).stdout)

def solved_at(src, dur):
    """Time of the last frame showing the completed word on its own clue: the clue card text changes
    when the game moves to the next clue (or to the "ممتاز!" card), often before the test logs SOLVED."""
    import numpy as np
    t0 = 1.0
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(src), "-vf",
                          f"trim={t0:.2f},crop=900:180:90:1440,scale=180:36,fps=20,format=gray", "-f", "rawvideo", "-"],
                         capture_output=True).stdout
    fr = np.frombuffer(raw, np.uint8).reshape(-1, 36, 180).astype(int)
    for i in range(len(fr) - 1):
        if abs(fr[i + 1] - fr[i]).mean() > 3: return t0 + i / 20 + 0.4   # the card flashes when the word is complete
    return dur - 0.15

def load_segments(rec):
    clues, levels = [], {}
    for line in (rec / "segments.tsv").read_text().splitlines():
        fname, start_line, _ = line.split("\t")
        head, _, clue = start_line.partition(" | ")
        _, kind, level, entry, answer = head.split(" ")[:5]
        src = cfr_proxy(rec / fname); dur = duration(src)
        lv = levels.setdefault(level, dict(level=level, ws="-w" in level, parts=[], complete=None))
        if kind == "CLUE":
            ws = "-w" in level
            end = (dur - 0.2) if ws else solved_at(src, dur)
            c = dict(level=level, entry=entry, answer=answer, clue=clue.strip(), ws=ws, src=src,
                     clue_t=0.0, type_t=1.2, solved_t=(end - 0.9) if ws else (end - 0.1))
            clues.append(c); lv["parts"].append((src, 0.0, end))
        elif kind == "COMPLETE":
            lv["complete"] = (src, 0.0, dur)
    return clues, [l for l in levels.values() if l["complete"]]

def speedrun_segments(lv, out):
    pack = lv["level"][:3]; ws = lv["ws"]
    hook = ("كلمات مخفية: " if ws else "لغز كامل: ") + PACK_TITLE.get(pack, "")
    total = sum(b - a for _, a, b in lv["parts"]); sp = max(1.0, total / 16)
    w = Writer(out); k = 0
    for src, a, b in lv["parts"]:
        for f in frames(src, a, b, sp):
            if k < 3 * FPS:
                label(f, hook, 60 if not ws else 1540, 64)
                label(f, "كم تاخذ أنت؟ (الفيديو مسرّع)", (60 if not ws else 1540) + 110, 44, fg=CREAM, bg=RED)
            w.put(f); k += 1
    src, a, b = lv["complete"]
    for f in frames(src, a, min(b, a + 3.5)): w.put(f)
    finish(w, lv["parts"][0][0], 0.5)

def video_start(rec):
    """Epoch time of the video's t=0. The simulator's timeline begins at the first screen change, a few
    seconds after it reports "Recording started", so use the exact end instead: stop time - duration."""
    stop = rec / "stop.txt"
    if stop.exists():
        dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                    str(rec / "gameplay.mp4")], capture_output=True, text=True).stdout)
        return float(stop.read_text()) - dur
    return float((rec / "start.txt").read_text())

def load(rec):
    start = video_start(rec)
    ev = []
    for line in (rec / "events.log").read_text().splitlines():
        head, _, clue = line.partition(" | ")
        t, kind, level, entry, answer = head.split(" ")[:5]
        ev.append(dict(t=float(t) - start, kind=kind, level=level, entry=entry, answer=answer, clue=clue))
    clues, levels, cur = [], [], {}
    for e in ev:
        if e["kind"] == "LEVEL": cur = dict(level=e["level"], start_t=e["t"], ws="-w" in e["level"])
        elif e["kind"] == "CLUE": clues.append(dict(level=e["level"], entry=e["entry"], answer=e["answer"], clue=e["clue"],
                                                    clue_t=e["t"], ws="-w" in e["level"]))
        elif e["kind"] == "TYPE": clues[-1]["type_t"] = e["t"]
        elif e["kind"] == "SOLVED": clues[-1]["solved_t"] = e["t"]
        elif e["kind"] == "COMPLETE": cur["complete_t"] = e["t"]; levels.append(cur)
    return [c for c in clues if "solved_t" in c], levels

def main():
    rec = Path(sys.argv[1]); only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    limit = int(sys.argv[sys.argv.index("--limit") + 1]) if "--limit" in sys.argv else 10**6
    for f in (APP / "Resources/Packs").glob("*.json"):
        p = json.loads(f.read_text()); PACK_TITLE[p["id"] if "id" in p else f.stem] = p.get("title_ar", "")
        for l in p["levels"]:
            for e in l["entries"]: CATEGORY[e["id"]] = e.get("category", "")
    out = rec / "videos"; out.mkdir(exist_ok=True)
    seg_mode = (rec / "segments.tsv").exists()
    # a recording folder, or a folder of per-level recordings (record.sh makes one per level)
    recs = [] if seg_mode else [rec] if (rec / "gameplay.mp4").exists() else sorted(
        d for d in rec.iterdir() if (d / "gameplay.mp4").exists() and (d / "events.log").stat().st_size)
    clues, levels = [], []
    for r in recs:
        s_ = cfr_proxy(r / "gameplay.mp4"); c_, l_ = load(r)
        for x in c_ + l_: x["src"] = s_
        clues += c_; levels += l_
    if seg_mode: clues, levels = load_segments(rec)
    rows = []; rnd = random.Random(7); made = 0
    def caption(text, pack, cat=""):
        return (f"{text}\n\nاللعبة: {NAME}، مجانية على App Store\n"
                f"#كلمات_متقاطعة #ألغاز #تحدي #لغز {CAT_TAGS.get(cat) or TAGS.get(pack, '')}").strip()
    if only in (None, "challenge", "ws"):
        for i, c in enumerate(clues):
            if made >= limit: break
            if c["ws"] and only == "challenge" or not c["ws"] and only == "ws": continue
            line2 = LINE2[i % len(LINE2)]
            name = f"{'ws' if c['ws'] else 'challenge'}-{c['level']}-{c['entry']}.mp4"
            if c["ws"]: ws_challenge(c["src"], c, out / name, line2)
            else:
                if "type_t" not in c: continue
                challenge(c["src"], c, out / name, line2)
            pack = c["level"][:3]
            hook = "دوّر على الكلمة" if c["ws"] else hook_for(c)
            rows.append(dict(file=name, format="ws" if c["ws"] else "challenge", hook=hook, line2=line2, level=c["level"],
                             clue=c["clue"], answer=c["answer"],
                             category=CATEGORY.get(c["entry"], ""),
                             caption=caption(f"{c['clue']}؟ {line2} 👇", pack, CATEGORY.get(c["entry"], ""))))
            made += 1; print("video", name, flush=True)
    if only in (None, "speedrun"):
        for lv in levels:
            if made >= limit: break
            name = f"speedrun-{lv['level']}.mp4"
            if seg_mode: speedrun_segments(lv, out / name)
            else: speedrun(lv["src"], lv, out / name, ws=lv["ws"])
            pack = lv["level"][:3]
            rows.append(dict(file=name, format="speedrun", hook="لغز كامل", line2="كم تاخذ أنت؟", level=lv["level"], clue="", answer="", category="",
                             caption=caption(f"لغز كامل من مجموعة «{PACK_TITLE.get(pack, '')}». كم تاخذ أنت؟ ومعدل ذكائك كم؟", pack)))
            made += 1; print("video", name, flush=True)
    with (out / "manifest.csv").open("w", newline="") as fh:
        wr = csv.DictWriter(fh, list(rows[0].keys())); wr.writeheader(); wr.writerows(rows)
    print(made, "videos ->", out)

if __name__ == "__main__":
    main()
