# Clue-writing brief (Arabic crossword, Gulf audience)

Every writer follows this exactly. Output is a UTF-8 CSV with this header:

```
id,answer,clue_ar,category,region,difficulty,image,source,reviewed_by,reviewed_at
```

## Columns
- **id** — your prefix + 3 digits (`gul001`…). Unique.
- **answer** — ONE Arabic word, letters only, no spaces, no tashkeel. 2–7 letters
  (8 max, rarely). Common nouns WITHOUT "ال" (نخلة, not النخلة). Proper names keep
  "ال" only when it is part of the name (الرياض, الكويت). The game maps أ إ آ → ا,
  ى → ي, ؤ → و, ئ → ي, so prefer words that still read naturally after that.
- **clue_ar** — Modern Standard Arabic, ≤ 70 characters, one clear answer, must not
  contain the answer or an obvious form of it. Neutral, factual, friendly.
- **category** — one of: `gulf, geography, general, language, nature, science, sport, history, religion, food`.
- **region** — `gulf` if specifically about the Gulf states (Saudi, UAE, Kuwait, Qatar,
  Bahrain, Oman), else `general`.
- **difficulty** — 1 easy (most adults know it), 2 medium, 3 hard. Aim ~50% / 35% / 15%.
- **image** — leave empty.
- **source** — a URL that confirms the fact (Arabic Wikipedia preferred). For any fact
  that is not universal common knowledge, CHECK it with a web search before writing it.
  If you cannot confirm a fact, drop the clue.
- **reviewed_by, reviewed_at** — leave EMPTY (a native reviewer fills them).

## Never
Politics, living politicians or royals, singers/actors/celebrities, alcohol, pork,
gambling, romance, sectarian or disputed religious topics, disputed borders or
names, anything mocking a nationality. No Quran verse text. No two rows with the
same answer, no two rows with the same clue.

## Good examples
```
gul001,دبي,مدينة إماراتية فيها أطول برج في العالم,gulf,gulf,1,,https://ar.wikipedia.org/wiki/برج_خليفة,,
geo001,النيل,أطول نهر في قارة أفريقيا,geography,general,1,,https://ar.wikipedia.org/wiki/نهر_النيل,,
lan001,ليل,عكس كلمة نهار,language,general,1,,https://ar.wiktionary.org/wiki/ليل,,
```
