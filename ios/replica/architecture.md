# Architecture: Arabic crossword (iOS)

From `recon.md` + `features.csv` (2026-11-14). Working name: **Crossword**
(real name comes from `/replica-brand`; bundle id placeholder
`com.zakaria.crossword` until then).

## 1. Stack

The Replica default is a web/Expo stack with Postgres. This app is offline,
single-player and iOS-only, so every server layer is dropped.

| layer | choice | why |
| --- | --- | --- |
| app | SwiftUI, iOS 18+, XcodeGen `project.yml` | same as Noor: known, reviewable, signing already solved |
| board rendering | SwiftUI `Grid`/`Canvas` (no SpriteKit) | ~10×10 cells max; SwiftUI handles it, keeps RTL + Dynamic Type for free |
| content | bundled JSON packs (`Resources/Packs/*.json`) | read-only, versioned in git, no server, works offline |
| progress | `Codable` file in Application Support + `NSUbiquitousKeyValueStore` mirror | tiny state (< 100 KB); iCloud KVS gives cross-device restore with no account (review complaint: lost progress) |
| IAP | StoreKit 2 (remove ads, coin packs), `.storekit` config for local testing | native, no SDK, no server receipt check needed for consumables + one non-consumable |
| ads | Google Mobile Ads (AdMob) via SPM + Google UMP consent | research: AdMob alone is fine below ~10k DAU; add AppLovin MAX later only if DAU justifies it |
| tracking | ATT prompt fired once, after the first completed level, straight from that moment (no pre-screen) | APP-STORE-REVIEW.md ⛔1: no custom card before the system dialog |
| font | bundled OFL Arabic Naskh font (e.g. Noto Naskh Arabic / Amiri) | review complaint: unreadable font; OFL allows bundling |
| tooling | Python 3 generator (`tools/`) | packs grids from the clue sheet offline; zero runtime cost |
| analytics | none at v1 | nothing to declare beyond AdMob in the privacy label |

No backend, no accounts, no database server.

## 2. The schema

There is no SQL: content is read-only JSON, progress is a local document.
Both have a strict schema in `schema.md` (this folder). Summary:

**Content (bundled, read-only)**
```
Pack    id, title_ar, order, region (gulf|general), levels[]
Level   id, number, width, height, entries[]
Entry   id, answer (canonical letters), row, col, dir (across|down),
        clue_ar, image? (asset name), category, difficulty 1-3
```
**Clue sheet (authoring source, `content/clues.csv`)** — one row per clue:
`id, answer, clue_ar, category, region, difficulty, image, source, reviewed_by, reviewed_at`.
A row without `reviewed_by` never reaches a pack (generator refuses it).

**State (local, `progress.json` + iCloud KVS)**
```
Progress  version, levels: {level_id: {filled: {"r,c": letter}, solved: [entry_id],
          hints_used, stars, completed_at}}, current_level_id
Wallet    coins, ads_removed (derived from StoreKit entitlement, never stored as truth)
Settings  sound, haptics, font_scale
```

Hard constraints (enforced by the generator, tested in CI-free `tools/validate.py`):
- every level's entries form one connected grid; every crossing letter matches
- answers only contain the canonical alphabet (see §4), length 2–9
- no answer repeats inside a pack; no clue text repeats across the app
- `stars` = 3 with 0 hints, 2 with ≤2, else 1 (our rule; the original's is unknown)

## 3. The "API" — internal services per flow

No HTTP routes. One Swift service per concern; views only talk to these.

| service | does | flow |
| --- | --- | --- |
| `ContentStore` | loads packs from bundle, `level(id)`, `next(after:)` | F01 |
| `GameEngine` (per level) | select entry, accept letter, check word, fill crossings, completion, stars | F01 |
| `LetterBank` | builds answer letters + decoys (seeded per entry, stable across launches) | F01 |
| `HintService` | reveal letter (cost 20), remove decoy (cost 10), rewarded-ad grant (+25) | F02 |
| `Wallet` | coin balance, spend/earn, start balance 100 | F02 F03 |
| `StoreService` | StoreKit 2 products, purchase, restore, `Transaction.updates` listener | F03 |
| `AdService` | UMP consent → init AdMob → rewarded + interstitial; frequency cap | F02 F03 |
| `ProgressStore` | save per keystroke (debounced), iCloud KVS merge (max progress wins) | F01 |
| `ShareService` | `ShareLink` with clue text + App Store link | F04 |

External calls, all official SDKs/APIs: StoreKit, Google Mobile Ads + UMP, iCloud KVS.
No background jobs. No webhooks.

**Ad policy (written down so the build can't drift):**
- rewarded: only when the user taps "watch for coins"
- interstitial: only between levels, ≥ 3 levels and ≥ 3 minutes apart, never in the first 3 levels
- no banners on the board; never an ad mid-word (review complaint)
- "Remove ads" removes interstitials; rewarded stays available (user-initiated)
- every ad unit **live** in the review build and described in review notes (⛔2: no flag-gated ads)
- "report this ad" path present (guideline 2.5.18 — AdMob's AdChoices icon covers it; verify)

## 4. The parts that bite

- **Arabic letter normalisation.** Canonical alphabet: 28 letters + ة + ء. Map أ إ آ ٱ → ا, ى → ي, ؤ → و, ئ → ي, strip tashkeel and tatweel. Applied to answers at generation time and to input at play time. ة stays distinct (it crosses words).
- **RTL.** Across words run right-to-left; `row,col` stored with col 0 = rightmost. Test with the layout direction forced both ways.
- **Isolated letter glyphs in cells.** Render each cell's single letter in the Naskh font; check ة, ء, ى render at cell size on iPhone 11 and SE.
- **Grid generation.** Packing 6–10 Arabic words with good crossings is a search problem; backtracking with a score (crossings, compactness) and a size cap (≤ 9×9). Seeded so regenerating is deterministic.
- **Content accuracy.** The #1 complaint class after ads. Every clue needs `reviewed_by`; Quran-verse clues are copied from a verified mushaf text, never typed.
- **Picture clues.** Flags and maps from public-domain sources (Wikimedia Commons PD/CC0, record the source in the sheet); no stock or web photos.
- **Offline / idempotency.** StoreKit `Transaction.updates` can redeliver: finish each transaction once, key consumables by transaction id.
- **iCloud KVS limits.** 1 MB / 1024 keys; store one compact blob, merge on `didChangeExternallyNotification`.
- **Consent.** UMP must run before the first ad request (EEA/UK). ATT is separate; AdMob serves non-personalised ads if denied.
- **iPad compatibility mode (⛔4).** iPhone-only, but the board and letter bank must fit the iPad compatibility window — test on the `iPad Air 11-inch M3` sim.
- **App size.** Keep images as small HEIC/PNG; the original is 63 MB, aim < 40 MB.

## 5. Build order

**M0 — vertical slice (2–3 days).** One hard-coded level from a 10-clue sheet →
generator → JSON → board (S04) → clue + letter bank (S05) → solved grid. No
coins, no ads. Proves RTL, letters, generator. Tables: Pack/Level/Entry, Progress.

**M1 — must-haves (1 week).** S01 home, S02 packs, S03 level picker with stars,
S06 level complete; hints + Wallet; progress per cell; normalisation; Naskh
font; picture clues. Generator + validator for the full sheet.

**M2 — monetisation, live (3–4 days).** StoreKit 2 (remove ads, 3 coin packs,
restore), S07 coins screen, AdMob rewarded + capped interstitial, UMP, ATT after
level 1 complete, privacy label + `PrivacyInfo.xcprivacy`. All live in the first
review build.

**M3 — should-haves (3–4 days).** Share a clue, report-a-clue (mailto with the
clue id), iCloud sync, Gulf pack, haptics/sound.

**M4 — content (parallel, the long pole).** 200 levels × ~8 = ~1,600 reviewed
clues for launch, Gulf + general packs. Draft, fact-check, native review.

**M5 — could-haves after launch.** Daily puzzle, Game Center leaderboard,
dark mode, picture-to-word mode.

Fixes from reviews are already folded into M1–M3 (ads cap, font,
normalisation, Gulf content, report a clue, sync).
