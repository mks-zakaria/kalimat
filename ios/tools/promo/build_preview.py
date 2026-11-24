"""Kalimat App Preview (App Store video, 886 x 1920) from the event-driven recording in rec2/.

    python3 build_preview.py ar|en      -> previews/kalimat-preview-<lang>.mp4

Scenes: two crossword clues solved (sped up), the «ممتاز!» card with the IQ score, two words found in the word
search. Captions describe what is on screen; no price, "free" or App Store wording (Apple's preview rules).
"""
import json, subprocess, sys
from pathlib import Path

HERE = Path(__file__).parent
REC = HERE / "rec2"
CAP = {
    "ar": ["اقرأ التعريف واكتب الكلمة", "كلمات متقاطعة بنكهة خليجية", "ممتاز! ومعدل ذكائك يتحدّث بعد كل لغز",
           "كلمات مخفية: ارسم خطًا فوق الكلمة", "٢٥٠ لغزًا في ٨ مجموعات"],
    "en": ["Read the clue, spell the word", "Arabic crosswords with a Gulf flavour", "Your IQ score updates after every puzzle",
           "Word search: draw a line over the word", "250 puzzles in 8 packs"],
}

def dur(f):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(f)],
                                capture_output=True, text=True).stdout)

def solve(name, caption, target=5.2):
    """A crossword clue file: the clue, then the word typed, sped up to about `target` seconds. Ends on the
    completed word (make_videos.solved_at), before the game moves on to the next clue."""
    sys.path.insert(0, str(HERE)); import make_videos as mv
    f = REC / name; proxy = mv.cfr_proxy(f)
    t0, t1 = 0.5, mv.solved_at(proxy, mv.duration(proxy)) + 0.3
    return {"file": str(f), "t0": t0, "t1": t1, "speed": (t1 - t0) / target, "caption": caption}

def clip(name, t0, t1_from_end, caption, speed=1.0):
    f = REC / name
    return {"file": str(f), "t0": t0, "t1": dur(f) - t1_from_end, "speed": speed, "caption": caption}

if __name__ == "__main__":
    lang = sys.argv[1]; c = CAP[lang]
    clips = [solve("seg-006.mp4", c[0]),                       # قرفة
             solve("seg-008.mp4", c[1]),                       # شاورما
             {"file": str(REC / "seg-011.mp4"), "t0": 0.3, "t1": 4.8, "speed": 1.0, "caption": c[2]},  # ممتاز! + IQ (app closes after ~5 s)
             clip("seg-081.mp4", 1.6, 0.4, c[3], 1.1),         # عباءة
             clip("seg-085.mp4", 1.6, 0.4, c[4], 1.1)]         # حناء
    out = HERE / "previews"; out.mkdir(exist_ok=True)
    sp = out / f"spec-{lang}.json"
    sp.write_text(json.dumps({"lang": lang, "clips": clips}, ensure_ascii=False, indent=1))
    subprocess.run([sys.executable, str(HERE / "make_preview.py"), str(sp), str(out / f"kalimat-preview-{lang}.mp4")], check=True)
