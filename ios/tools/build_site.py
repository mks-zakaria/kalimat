#!/usr/bin/env python3
"""Build the website into ../web/ (next to ios/ in the kalimat repo) from site-src/ and the app's puzzle packs.

    python3 tools/build_site.py [--base-url https://example.com/kalimat]

- site-src/pages/*.html: page bodies. The first lines are meta comments:
      <!--title: ...-->  <!--description: ...-->  <!--heading: ...-->  <!--hero: big|small-->
  Everything after them is the page's <main> content.
- app/Resources/Packs/*.json: one answers page per puzzle (answers/p01-001.html),
  one page per pack (answers/p01.html) and a hub (answers/index.html).
- Word search: the app's own Swift generator is compiled and run (tools/export_wordsearch.swift)
  so the grids match the game exactly: answers/p01-w001.html, answers/ws-p01.html.
- site-src/static/: copied as-is (stylesheet, icons, self-hosted font).

Every page gets the same <head> (title, description, Open Graph, icons) and footer.
With --base-url, pages also get a canonical link and a sitemap.xml is written.
Standard library only.
"""
import argparse, glob, html, json, os, re, shutil, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "site-src")
OUT = os.path.join(os.path.dirname(ROOT), "web")   # sibling folder in the kalimat repo: web/
# Files in web/ that the build does not produce and must keep.
KEEP = {".git", ".gitignore", "README.md", "vercel.json"}
PACKS = os.path.join(ROOT, "app", "Resources", "Packs")
WS_CACHE = os.path.join(SRC, "wordsearch.json")   # last export, used when swiftc is unavailable

APP = "كلمات"
APP_EN = "Kalimat"
PUBLISHER = "Zakaria Makhkhas"
EMAIL = "makhkhas.zakaria@gmail.com"

CATEGORIES = {"gulf": "الخليج", "geography": "جغرافيا", "religion": "ديني", "sport": "رياضة",
              "science": "علوم", "language": "لغة", "food": "مأكولات", "history": "تاريخ",
              "flags": "أعلام"}

WEB_REPO_FILES = {
    ".gitignore": ".claude/\n.DS_Store\n.vercel\n",
    "README.md": """# Kalimat — website

Static site for the Kalimat (كلمات) Arabic crossword app: landing page, privacy policy,
general terms of use, support, and puzzle answers.

**Generated — do not edit here.** The sources live in the app repository
(`site-src/` and `tools/build_site.py`); run `python3 tools/build_site.py` there and commit
the result in this repo. Deployed as a static site (no build step).
""",
}

TASHKEEL = re.compile("[ً-ْٰـ\\s]")


def ar(n):
    return str(n).translate(str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩"))


def count(n, one, two, few, many):
    """Arabic number agreement: 1 word, 2 dual, 3-10 plural, 11+ singular accusative."""
    if n == 1: return one
    if n == 2: return two
    if 3 <= n % 100 <= 10: return f"{ar(n)} {few}"
    return f"{ar(n)} {many}"


def letters(answer):
    """Same as the app's ArabicText.normalise: drop tashkeel, tatweel and spaces."""
    return list(TASHKEEL.sub("", answer).replace("ٱ", "ا"))


def esc(s):
    return html.escape(s, quote=True)


# ---------------------------------------------------------------- layout

def page(path, title, description, heading, body, hero="small", base_url=None, extra_head=""):
    depth = path.count("/")
    up = "../" * depth
    canonical = ""
    if base_url:
        url = base_url.rstrip("/") + "/" + ("" if path == "index.html" else path)
        canonical = f'<link rel="canonical" href="{esc(url)}">\n<meta property="og:url" content="{esc(url)}">\n'
    og_image = f'{base_url.rstrip("/")}/icon.png' if base_url else f"{up}icon.png"
    hero_html = (
        f'<header class="hero{"" if hero == "big" else " small"}">\n'
        f'  <a href="{up}index.html"><img src="{up}icon.png" alt="أيقونة لعبة {APP}"></a>\n'
        f'  <h1>{heading}</h1>\n'
        + (f'  <p>كلمات متقاطعة بالعربية، بتعريفات من الخليج والعالم العربي، في لغز قصير تحلّه في دقائق.</p>\n'
           f'  <span class="soon">قريبًا على App Store</span>\n' if hero == "big" else "")
        + "</header>"
    )
    nav = [("index.html", "الرئيسية"), ("answers/index.html", "حلول الألغاز"),
           ("privacy.html", "الخصوصية"), ("terms.html", "الشروط العامة"), ("support.html", "الدعم")]
    nav_html = "\n".join(
        f'    <a href="{up}{href}"{" aria-current=\"page\"" if href == path or (href.startswith("answers/") and path.startswith("answers/")) else ""}>{label}</a>'
        for href, label in nav)
    return f"""<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(description)}">
<meta name="robots" content="index, follow">
<meta property="og:type" content="website">
<meta property="og:site_name" content="{APP}">
<meta property="og:locale" content="ar_AR">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(description)}">
<meta property="og:image" content="{esc(og_image)}">
<meta name="twitter:card" content="summary">
{canonical}<meta name="theme-color" content="#3B2A5C">
<link rel="icon" href="{up}icon.png">
<link rel="apple-touch-icon" href="{up}apple-touch-icon.png">
<link rel="preload" href="{up}fonts/NotoNaskhArabic.woff" as="font" type="font/woff" crossorigin>
<link rel="stylesheet" href="{up}style.css">
{extra_head}</head>
<body>
<a class="skip" href="#main">تخطَّ إلى المحتوى</a>
{hero_html}

<main class="wrap" id="main">
  <nav class="top" aria-label="روابط الموقع">
{nav_html}
  </nav>
{body}
</main>

<footer>
  <nav aria-label="روابط قانونية">
    <a href="{up}answers/index.html">حلول الألغاز</a> ·
    <a href="{up}privacy.html">سياسة الخصوصية</a> ·
    <a href="{up}terms.html">الشروط العامة للاستخدام</a> ·
    <a href="{up}privacy.html#cookies">ملفات تعريف الارتباط</a> ·
    <a href="{up}support.html">الدعم</a> ·
    <a href="mailto:{EMAIL}">تواصل معنا</a>
  </nav>
  <nav class="en" lang="en" dir="ltr" aria-label="Legal links">
    <a href="{up}privacy.html#english">Privacy</a> · <a href="{up}terms.html#english">Terms of use</a> ·
    <a href="{up}privacy.html#en-cookies">Cookies</a> · <a href="{up}support.html#english">Support</a>
  </nav>
  <p>© ٢٠٢٦ <span dir="ltr">{PUBLISHER}</span></p>
</footer>
</body>
</html>
"""


def read_source(fname):
    with open(fname, encoding="utf-8") as f:
        text = f.read()
    meta = dict(re.findall(r"<!--(\w+):\s*(.*?)\s*-->", text.split("\n\n", 1)[0]))
    body = re.sub(r"\A(\s*<!--\w+:.*?-->\s*)+", "", text)
    for k in ("title", "description", "heading"):
        if k not in meta:
            raise SystemExit(f"{fname}: missing <!--{k}: ...-->")
    return meta, body


# ---------------------------------------------------------------- answers

def grid_html(level):
    h, w = level["height"], level["width"]
    cells = [[None] * w for _ in range(h)]
    for e in level["entries"]:
        r, c = e["row"], e["col"]
        for ch in letters(e["answer"]):
            cells[r][c] = ch
            if e["dir"] == "across":
                c += 1          # column 0 is the rightmost; across runs right to left
            else:
                r += 1
    rows = []
    for row in cells:
        tds = "".join(f'<td class="on">{esc(ch)}</td>' if ch else '<td></td>' for ch in row)
        rows.append(f"<tr>{tds}</tr>")
    return f'<table class="xgrid" aria-label="الشبكة محلولة">{"".join(rows)}</table>'


def entry_order(level):
    return sorted(level["entries"], key=lambda e: (e["dir"] != "across", e["row"], e["col"]))


def level_page(pack, level, prev_id, next_id, base_url):
    n = level["number"]
    entries = entry_order(level)
    title = f"حل لغز {ar(n)} – {pack['title_ar']} | {APP}"
    clues = "، ".join(e["clue_ar"] for e in entries[:2])
    description = (f"إجابات اللغز {ar(n)} من حزمة «{pack['title_ar']}» في لعبة {APP} للكلمات المتقاطعة: "
                   f"{count(len(entries), 'كلمة', 'كلمتان', 'كلمات', 'كلمة')}، منها: {clues}.")
    items = []
    for e in entries:
        cat = CATEGORIES.get(e.get("category"), "معلومات عامة")
        d = "أفقي" if e["dir"] == "across" else "عمودي"
        items.append(
            f'<details class="clue"><summary><span class="tag">{d} · {cat} · {count(len(letters(e["answer"])), "حرف واحد", "حرفان", "حروف", "حرفًا")}</span>'
            f'{esc(e["clue_ar"])}</summary><p class="answer">{esc(e["answer"])}</p></details>')
    pager = []
    if prev_id:
        pager.append(f'<a href="{prev_id}.html" rel="prev">→ اللغز السابق</a>')
    pager.append(f'<a href="{pack["id"]}.html">كل ألغاز الحزمة</a>')
    if next_id:
        pager.append(f'<a href="{next_id}.html" rel="next">اللغز التالي ←</a>')
    body = f"""
  <p class="crumbs"><a href="index.html">حلول الألغاز</a> ‹ <a href="{pack['id']}.html">{esc(pack['title_ar'])}</a> ‹ اللغز {ar(n)}</p>
  <p class="lead">اضغط على التعريف لترى إجابته وحدها، أو افتح الشبكة كاملة في الأسفل.</p>
  {''.join(items)}
  <details class="full"><summary>أظهر الشبكة محلولة</summary>{grid_html(level)}</details>
  <nav class="pager" aria-label="التنقل بين الألغاز">{' '.join(pager)}</nav>
"""
    return page(f"answers/{level['id']}.html", title, description,
                f"حل اللغز {ar(n)}", body, base_url=base_url)


def pack_page(pack, base_url):
    rows = []
    for lv in pack["levels"]:
        first = entry_order(lv)[0]["clue_ar"]
        rows.append(f'<li><a href="{lv["id"]}.html"><strong>اللغز {ar(lv["number"])}</strong></a>'
                    f' <span class="muted">— {count(len(lv["entries"]), "كلمة", "كلمتان", "كلمات", "كلمة")}، أولها: {esc(first)}</span></li>')
    n_lv = count(len(pack['levels']), "لغز واحد", "لغزان", "ألغاز", "لغزًا")
    title = f"حلول حزمة {pack['title_ar']} – {n_lv} | {APP}"
    description = (f"إجابات كل ألغاز حزمة «{pack['title_ar']}» (الحزمة {ar(pack['order'])}) في لعبة {APP}: "
                   f"{n_lv} من الكلمات المتقاطعة العربية مع التعريفات.")
    body = f"""
  <p class="crumbs"><a href="index.html">حلول الألغاز</a> ‹ {esc(pack['title_ar'])}</p>
  <ol class="levels">{''.join(rows)}</ol>
"""
    return page(f"answers/{pack['id']}.html", title, description,
                f"حلول حزمة {esc(pack['title_ar'])}", body, base_url=base_url)


def hub_page(packs, ws_packs, base_url):
    def cards(ps):
        return "".join(
            f'<a class="card link" href="{p["id"]}.html"><h3>{ar(p["order"])}. {esc(p["title_ar"])}</h3>'
            f'<p>{count(len(p["levels"]), "لغز واحد", "لغزان", "ألغاز", "لغزًا")}</p></a>' for p in ps)
    total = sum(len(p["levels"]) for p in packs)
    ws_total = sum(len(p["levels"]) for p in ws_packs)
    body = f"""
  <p class="lead">علقت في لغز؟ اختر طريقة اللعب، ثم الحزمة، ثم رقم اللغز. كل إجابة مخفيّة حتى تضغط على تعريفها، فلن ترى إلا ما تحتاجه.</p>
  <h2 id="crossword">كلمات متقاطعة <span class="muted">({count(total, "لغز واحد", "لغزان", "ألغاز", "لغزًا")})</span></h2>
  <div class="grid">{cards(packs)}</div>
  <h2 id="wordsearch">كلمات مخفية <span class="muted">({count(ws_total, "لغز واحد", "لغزان", "ألغاز", "لغزًا")})</span></h2>
  <p class="muted">ابحث عن الكلمة في مربع الحروف وارسم خطًا فوقها: أفقيًا أو عموديًا أو قطريًا.</p>
  <div class="grid">{cards(ws_packs)}</div>
"""
    return page("answers/index.html",
                f"حلول ألغاز {APP} – الكلمات المتقاطعة والكلمات المخفية",
                f"إجابات كل ألغاز لعبة {APP}: {count(total, 'لغز', 'لغزان', 'ألغاز', 'لغزًا')} كلمات متقاطعة و"
                f"{count(ws_total, 'لغز', 'لغزان', 'ألغاز', 'لغزًا')} كلمات مخفية، مرتّبة حسب الحزمة ورقم اللغز.",
                "حلول الألغاز", body, base_url=base_url)


# ---------------------------------------------------------------- word search

DIRECTION_AR = {(0, 1): "أفقي", (1, 0): "عمودي", (1, 1): "قطري", (1, -1): "قطري"}


def load_wordsearch():
    """Word-search levels exactly as the app builds them: compile and run the app's own
    Swift generator (tools/export_wordsearch.swift). Falls back to the last export."""
    app = os.path.join(ROOT, "app")
    try:
        with tempfile.TemporaryDirectory() as tmp:
            exe, out = os.path.join(tmp, "wsexport"), os.path.join(tmp, "ws.json")
            sources = [os.path.join(app, "tools", "export_wordsearch.swift"),
                       os.path.join(app, "Sources", "Models", "Content.swift")] + \
                sorted(glob.glob(os.path.join(app, "Sources", "Game", "*.swift")))
            subprocess.run(["swiftc", "-O", "-parse-as-library", *sources, "-o", exe],
                           check=True, capture_output=True)
            subprocess.run([exe, PACKS, out], check=True, capture_output=True)
            shutil.copyfile(out, WS_CACHE)
    except (OSError, subprocess.CalledProcessError) as e:
        print(f"warning: word-search export failed ({e}); using {os.path.relpath(WS_CACHE, ROOT)}")
    with open(WS_CACHE, encoding="utf-8") as f:
        return json.load(f)


def ws_grid_html(level):
    owner = {}
    for i, e in enumerate(level["entries"]):
        for r, c in e["cells"]:
            owner.setdefault((r, c), i)
    rows = []
    for r, row in enumerate(level["grid"]):
        tds = "".join(f'<td class="hit w{owner[(r, c)] % 8}">{esc(ch)}</td>' if (r, c) in owner
                      else f"<td>{esc(ch)}</td>" for c, ch in enumerate(row))
        rows.append(f"<tr>{tds}</tr>")
    return f'<table class="xgrid ws" aria-label="مربع الحروف مع الكلمات ملوّنة">{"".join(rows)}</table>'


def ws_level_page(pack, level, prev_id, next_id, base_url):
    n = level["number"]
    entries = level["entries"]
    title = f"حل كلمات مخفية {ar(n)} – {pack['title_ar']} | {APP}"
    clues = "، ".join(e["clue_ar"] for e in entries[:2])
    description = (f"إجابات لغز الكلمات المخفية {ar(n)} من حزمة «{pack['title_ar']}» في لعبة {APP}: "
                   f"{count(len(entries), 'كلمة', 'كلمتان', 'كلمات', 'كلمة')} في مربع "
                   f"{ar(level['size'])}×{ar(level['size'])}، منها: {clues}.")
    items = []
    for i, e in enumerate(entries):
        cat = CATEGORIES.get(e.get("category"), "معلومات عامة")
        d = DIRECTION_AR[(e["dr"], e["dc"])]
        items.append(
            f'<details class="clue"><summary><span class="tag"><i class="dot w{i % 8}"></i>{d} · {cat} · '
            f'{count(len(letters(e["answer"])), "حرف واحد", "حرفان", "حروف", "حرفًا")}</span>'
            f'{esc(e["clue_ar"])}</summary><p class="answer">{esc(e["answer"])}</p></details>')
    pager = []
    if prev_id:
        pager.append(f'<a href="{prev_id}.html" rel="prev">→ اللغز السابق</a>')
    pager.append(f'<a href="{pack["id"]}.html">كل ألغاز الحزمة</a>')
    if next_id:
        pager.append(f'<a href="{next_id}.html" rel="next">اللغز التالي ←</a>')
    body = f"""
  <p class="crumbs"><a href="index.html#wordsearch">حلول الكلمات المخفية</a> ‹ <a href="{pack['id']}.html">{esc(pack['title_ar'])}</a> ‹ اللغز {ar(n)}</p>
  <p class="lead">اضغط على التعريف لترى إجابته واتجاهها، أو افتح المربع كاملًا في الأسفل، كل كلمة بلون.</p>
  {''.join(items)}
  <details class="full"><summary>أظهر المربع محلولًا</summary>{ws_grid_html(level)}</details>
  <nav class="pager" aria-label="التنقل بين الألغاز">{' '.join(pager)}</nav>
"""
    return page(f"answers/{level['id']}.html", title, description,
                f"حل الكلمات المخفية {ar(n)}", body, base_url=base_url)


def ws_pack_page(pack, base_url):
    rows = []
    for lv in pack["levels"]:
        rows.append(f'<li><a href="{lv["id"]}.html"><strong>اللغز {ar(lv["number"])}</strong></a>'
                    f' <span class="muted">— {count(len(lv["entries"]), "كلمة", "كلمتان", "كلمات", "كلمة")}، '
                    f'أولها: {esc(lv["entries"][0]["clue_ar"])}</span></li>')
    n_lv = count(len(pack["levels"]), "لغز واحد", "لغزان", "ألغاز", "لغزًا")
    title = f"حلول الكلمات المخفية – {pack['title_ar']} – {n_lv} | {APP}"
    description = (f"إجابات كل ألغاز الكلمات المخفية في حزمة «{pack['title_ar']}» (الحزمة {ar(pack['order'])}) "
                   f"في لعبة {APP}: {n_lv} مع التعريفات واتجاه كل كلمة.")
    body = f"""
  <p class="crumbs"><a href="index.html#wordsearch">حلول الكلمات المخفية</a> ‹ {esc(pack['title_ar'])}</p>
  <ol class="levels">{''.join(rows)}</ol>
"""
    return page(f"answers/{pack['id']}.html", title, description,
                f"كلمات مخفية: {esc(pack['title_ar'])}", body, base_url=base_url)


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default=os.environ.get("SITE_BASE_URL", "https://kalimat-web.vercel.app"))
    args = ap.parse_args()

    # web/ (deployed on Vercel) is rebuilt from scratch: clear everything the build makes.
    # Refuse to run unless it really is the site folder of this repo, so a wrong path never
    # empties another folder.
    repo = os.path.dirname(ROOT)
    if not (os.path.isdir(os.path.join(repo, ".git")) and os.path.isfile(os.path.join(OUT, "app-ads.txt"))):
        raise SystemExit(f"{OUT} is not the kalimat site folder (expected web/app-ads.txt in the kalimat repo).")
    for name in os.listdir(OUT):
        if name in KEEP:
            continue
        target = os.path.join(OUT, name)
        shutil.rmtree(target) if os.path.isdir(target) and not os.path.islink(target) else os.remove(target)
    shutil.copytree(os.path.join(SRC, "static"), OUT, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns(".claude", ".DS_Store", "__pycache__"))
    for name, text in WEB_REPO_FILES.items():
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            f.write(text)
    written = []

    def write(rel, text):
        dest = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8") as f:
            f.write(text)
        written.append(rel)

    for fname in sorted(glob.glob(os.path.join(SRC, "pages", "*.html"))):
        meta, body = read_source(fname)
        rel = os.path.basename(fname)
        write(rel, page(rel, meta["title"], meta["description"], meta["heading"], body,
                        hero=meta.get("hero", "small"), base_url=args.base_url))

    packs = []
    for f in sorted(glob.glob(os.path.join(PACKS, "*.json"))):
        with open(f, encoding="utf-8") as fh:
            packs.append(json.load(fh))
    packs.sort(key=lambda p: p["order"])
    all_levels = [(p, lv) for p in packs for lv in p["levels"]]
    for i, (p, lv) in enumerate(all_levels):
        prev_id = all_levels[i - 1][1]["id"] if i > 0 else None
        next_id = all_levels[i + 1][1]["id"] if i + 1 < len(all_levels) else None
        write(f"answers/{lv['id']}.html", level_page(p, lv, prev_id, next_id, args.base_url))
    for p in packs:
        write(f"answers/{p['id']}.html", pack_page(p, args.base_url))
    ws_packs = load_wordsearch()
    ws_levels = [(p, lv) for p in ws_packs for lv in p["levels"]]
    for i, (p, lv) in enumerate(ws_levels):
        prev_id = ws_levels[i - 1][1]["id"] if i > 0 else None
        next_id = ws_levels[i + 1][1]["id"] if i + 1 < len(ws_levels) else None
        write(f"answers/{lv['id']}.html", ws_level_page(p, lv, prev_id, next_id, args.base_url))
    for p in ws_packs:
        write(f"answers/{p['id']}.html", ws_pack_page(p, args.base_url))
    write("answers/index.html", hub_page(packs, ws_packs, args.base_url))

    if args.base_url:
        base = args.base_url.rstrip("/")
        urls = "\n".join(f"  <url><loc>{base}/{'' if r == 'index.html' else r}</loc></url>" for r in sorted(written))
        write("sitemap.xml", f'<?xml version="1.0" encoding="UTF-8"?>\n'
                             f'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{urls}\n</urlset>\n')
        write("robots.txt", f"User-agent: *\nAllow: /\nSitemap: {base}/sitemap.xml\n")

    print(f"web/: {len(written)} pages ({len(all_levels)} crossword + {len(ws_levels)} word-search answer pages)"
          + ("" if args.base_url else " — no --base-url, so no canonical links or sitemap"))


if __name__ == "__main__":
    main()
