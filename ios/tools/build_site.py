#!/usr/bin/env python3
"""Build the website into site/ from site-src/ and the app's puzzle packs.

    python3 tools/build_site.py [--base-url https://example.com/kalimat]

- site-src/pages/*.html: page bodies. The first lines are meta comments:
      <!--title: ...-->  <!--description: ...-->  <!--heading: ...-->  <!--hero: big|small-->
  Everything after them is the page's <main> content.
- app/Resources/Packs/*.json: one answers page per puzzle (answers/p01-001.html),
  one page per pack (answers/p01.html) and a hub (answers/index.html).
- site-src/static/: copied as-is (stylesheet, icons, self-hosted font).

Every page gets the same <head> (title, description, Open Graph, icons) and footer.
With --base-url, pages also get a canonical link and a sitemap.xml is written.
Standard library only.
"""
import argparse, glob, html, json, os, re, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "site-src")
OUT = os.path.join(ROOT, "site")
PACKS = os.path.join(ROOT, "app", "Resources", "Packs")

APP = "كلمات"
APP_EN = "Kalimat"
PUBLISHER = "Zakaria Makhkhas"
EMAIL = "makhkhas.zakaria@gmail.com"

CATEGORIES = {"gulf": "الخليج", "geography": "جغرافيا", "religion": "ديني", "sport": "رياضة",
              "science": "علوم", "language": "لغة", "food": "مأكولات", "history": "تاريخ",
              "flags": "أعلام"}

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


def hub_page(packs, base_url):
    total = sum(len(p["levels"]) for p in packs)
    cards = []
    for p in packs:
        cards.append(f'<a class="card link" href="{p["id"]}.html"><h3>{ar(p["order"])}. {esc(p["title_ar"])}</h3>'
                     f'<p>{count(len(p["levels"]), "لغز واحد", "لغزان", "ألغاز", "لغزًا")}</p></a>')
    body = f"""
  <p class="lead">علقت في لغز؟ اختر الحزمة ثم رقم اللغز. كل تعريف مخفيّ حتى تضغط عليه، فلن ترى إلا الإجابة التي تحتاجها.</p>
  <div class="grid">{''.join(cards)}</div>
"""
    return page("answers/index.html", f"حلول ألغاز {APP} – {ar(total)} لغزًا في {ar(len(packs))} حزم",
                f"إجابات كل ألغاز لعبة {APP} للكلمات المتقاطعة العربية: {ar(total)} لغزًا مرتّبة حسب الحزمة ورقم اللغز.",
                "حلول الألغاز", body, base_url=base_url)


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default=os.environ.get("SITE_BASE_URL"))
    args = ap.parse_args()

    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    shutil.copytree(os.path.join(SRC, "static"), OUT)
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
    write("answers/index.html", hub_page(packs, args.base_url))

    if args.base_url:
        base = args.base_url.rstrip("/")
        urls = "\n".join(f"  <url><loc>{base}/{'' if r == 'index.html' else r}</loc></url>" for r in sorted(written))
        write("sitemap.xml", f'<?xml version="1.0" encoding="UTF-8"?>\n'
                             f'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{urls}\n</urlset>\n')
        write("robots.txt", f"User-agent: *\nAllow: /\nSitemap: {base}/sitemap.xml\n")

    print(f"site/: {len(written)} pages ({len(all_levels)} puzzle answer pages)"
          + ("" if args.base_url else " — no --base-url, so no canonical links or sitemap"))


if __name__ == "__main__":
    main()
