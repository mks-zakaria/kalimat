"""App Store App Preview from real simulator footage (event-driven segment files, see watch_record.py).

    python3 make_preview.py <spec.json> <out.mp4>

spec: {"lang": "ar", "clips": [{"file": "/abs/seg-003.mp4", "t0": 0.5, "t1": 6.0, "speed": 1.0, "caption": "…"}, …]}

Apple's rules (App Store Connect › App preview specifications; guideline 2.3.4):
- iPhone 6.9"/6.5" portrait 886 x 1920, 15–30 s, H.264, ≤ 30 fps, up to 3 per locale.
- Footage of the app itself. Text overlays are fine; no prices, no "free", no App Store wording, no end card.
The simulator records 1206 x 2622 (aspect 0.460), so the full screen scales to 886 x 1925 and loses 2.5 px at
top and bottom: the preview is the real screen, status bar and tab bar included. Each clip is decoded from the
start of its file (exact; seeking into the simulator's variable-frame-rate files is not).
Same file in ios/tools/promo/.
"""
import json, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 886, 1920, 30
AR, LAT, MIX = "/System/Library/Fonts/SFArabic.ttf", "/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Supplemental/Tahoma Bold.ttf"

_fc = {}
def font(s, size):
    ar = any("؀" <= c <= "ۿ" for c in s); lat = any(c.isascii() and c.isalpha() for c in s)
    path = MIX if ar and lat else (AR if ar else LAT)
    if (path, size) not in _fc:
        f = ImageFont.truetype(path, size, layout_engine=ImageFont.Layout.RAQM)
        try: f.set_variation_by_name("Bold")
        except Exception: pass
        _fc[(path, size)] = f
    return _fc[(path, size)], ("rtl" if ar else None)

def caption_layer(text, y=118, size=46):
    """A dark pill near the top (over the status/title area), white bold text."""
    o = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(o)
    while True:
        f, dr = font(text, size); w = d.textlength(text, font=f, direction=dr)
        if w <= W * 0.86 or size < 26: break
        size = int(size * 0.94)
    a, de = f.getmetrics(); px, py = int(size * 0.55), int(size * 0.3)
    x0 = (W - w) / 2 - px
    d.rounded_rectangle([x0, y, x0 + w + 2 * px, y + a + de + 2 * py], radius=int(size * 0.6), fill=(12, 22, 18, 225))
    d.text(((W - w) / 2, y + py), text, font=f, fill=(255, 255, 255, 255), direction=dr)
    return o

def clip_frames(c):
    sp = c.get("speed", 1.0)
    vf = (f"trim=start={c['t0']}:end={c['t1']},setpts=(PTS-STARTPTS)/{sp},fps={FPS},"
          f"scale={W}:-2:flags=lanczos,crop={W}:{H}")
    p = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-i", c["file"], "-vf", vf, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         stdout=subprocess.PIPE)
    n = W * H * 3
    while True:
        b = p.stdout.read(n)
        if len(b) < n: break
        yield Image.frombytes("RGB", (W, H), b)
    p.wait()

def main():
    spec = json.loads(Path(sys.argv[1]).read_text()); out = Path(sys.argv[2])
    enc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                            "-r", str(FPS), "-i", "-", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-shortest",
                            "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-preset", "slow", "-crf", "18",
                            "-pix_fmt", "yuv420p", "-r", str(FPS), "-movflags", "+faststart",
                            "-c:a", "aac", "-b:a", "128k", str(out)], stdin=subprocess.PIPE)
    n = 0
    for c in spec["clips"]:
        cap = caption_layer(c["caption"]) if c.get("caption") else None
        k = 0
        for f in clip_frames(c):
            if cap is not None: f.paste(cap, (0, 0), cap)
            if k < 6 and n > 0:                      # short fade-in from black between scenes
                f = Image.blend(Image.new("RGB", (W, H)), f, (k + 1) / 7)
            enc.stdin.write(f.tobytes()); k += 1; n += 1
    enc.stdin.close(); enc.wait()
    dur = n / FPS
    print(f"{out.name}: {dur:.1f} s, {W}x{H}")
    if not 15 <= dur <= 30: raise SystemExit(f"duration {dur:.1f}s outside Apple's 15-30 s")

if __name__ == "__main__":
    main()
