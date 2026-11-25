# Recon map: Arabic crossword games (iOS)

Scope: the core loop only — pick a level → solve a small crossword one clue at a
time → hints → level complete → next level. Plus the coins/ads economy around it.
For: the user's own Gulf-focused Arabic crossword (free + ads + remove-ads IAP),
SwiftUI/SpriteKit, iPhone first.
Date: 2026-11-14

Clean-room: features and flow only. None of the originals' clues, images,
names, art or text go into our app. Screenshots in `screens/` are reference.

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | App Store listing — كلمات متقاطعة: أفضل لعبة عربية (Finjan Games) | https://apps.apple.com/sa/app/id1089531949 | 2,778 ratings, 4.5★, v1.56 (2025-07), 63 MB, iOS 11+, 4+, has IAP. Est. 76k MAU, ~$5.8k/mo ads (AppGoblin). 6 screenshots |
| 2 | App Store listing — وصلة - الجزء الثاني (Finjan Games) | https://apps.apple.com/sa/app/id1039759784 | 633 ratings, v1.2.6 (2024-07). Description lists clue categories + "answer is checked as you type". 2 screenshots |
| 3 | Play listing — كلمات متقاطعة للكبار - بدون نت | https://play.google.com/store/apps/details?id=com.mohanadgames.crossn | 100K+ installs, est. 9.3k installs/mo, ~$2.6k/mo. "8 words per grid", difficulty ramps, offline |
| 4 | Play listing — كلمات متقاطعة وصور وصلة | https://play.google.com/store/apps/details?id=appstore.game.crosswords.game | 1M+ installs, ~$5.4k/mo ads. Variant: 4 pictures → find words in a letter grid → leftover letters solve a final riddle |
| 5 | User reviews (613, App Store RSS) | ../replica/reviews.csv | complaints read by hand — see "Fixes from reviews" |
| 6 | Install/revenue data | ../../demand.csv | AppGoblin estimates + Play ranges |

No help center, changelog or walkthrough video was found for these apps
(release notes are just "General fixes"/"تعديلات").

## Core loop

Tap a word in a small crossword, read its clue (text or picture), spell the
answer from a letter bank; each solved word drops shared letters into the
crossing words, until the grid is full.

## Screens

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Home | launch | start / continue | title art, play button (guess: settings, more-apps) | default |
| S02 | Group list | S01 → play | choose a level pack | group cards ("المجموعة السادسة"), total stars | locked/unlocked (guess) |
| S03 | Level picker | S02 → group | choose a level | numbered tiles with 0–3 stars, header with back + star count | solved (3★), unsolved (0★), locked (guess) |
| S04 | Crossword board | S03 → level | see the grid, pick a word | grid of cells (empty white / filled with letter / block), header: back, "لغز رقم N", stars | empty, partly filled |
| S05 | Clue + answer | S04 → tap a word | solve one word | clue card (category label, text **or** image), share button, hint buttons "إحذف حرف" / "إكشف حرف", answer slots, letter bank (~12–14 letters), coin balance with "+" | empty, partly typed, revealed letter (yellow), solved (guess: animation) |
| S06 | Level complete | S04 when grid full | reward | stars, next (guess — not in screenshots) | — |
| S07 | Get coins | header "+" | buy/earn coins | coin packs, watch-ad option (guess) | — |
| S08 | Share | S05 share icon | ask a friend for help | system share sheet with the clue | — |

## Flows

```
F01 Solve a level
    S01 -> S02 -> S03 -> S04 -> (tap word -> S05 -> type answer) x ~8 -> S06 -> S04 next
    happy path taps: 3 to reach the board, then per word: 1 to open + N letters
    edge: wrong letter (checked as typed, per Wasla listing), all letters known from
          crossings, leaving mid-word, returning to a partly solved level
F02 Use a hint
    S05 -> "إكشف حرف" (reveal one letter, coins) or "إحذف حرف" (remove a wrong letter from the bank, coins)
    edge: not enough coins -> S07
F03 Get coins
    header "+" -> S07 -> buy pack / (guess) watch rewarded ad -> back to S05
F04 Ask a friend
    S05 -> share -> system sheet
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Grid cell | empty, letter, block | normal, selected word, revealed (hint), correct | S04 |
| Clue card | text, image, category header | — | S05 |
| Answer slot | — | empty, typed, hint-revealed (yellow), wrong (guess) | S05 |
| Letter key | — | normal, used, removed by hint | S05 |
| Hint button | reveal, remove | enabled, no coins | S05 |
| Level tile | number + 0–3 stars | locked, open, solved | S03 |
| Group card | — | locked, open | S02 |
| Top bar | back, title, stars or coins + "+" | — | S03–S05 |

## Inferred data model

```
Group    id, title, order, levels[]                 evidence: S02, S03 header   confidence: medium
Level    id, group_id, number, width, height, entries[]
                                                    evidence: S04 grids are small (~8 words, Play #3 says 8)
                                                    confidence: high
Entry    id, level_id, answer (Arabic, isolated letters), row, col, direction (across|down),
         clue_text?, clue_image?, category (معلومات عامة | ديني | أعلام | ...)
                                                    evidence: S05 cards, Wasla category list   confidence: high
Progress level_id, letters_filled (map cell->letter), solved_entry_ids, stars
                                                    evidence: stars on S03, partial grids   confidence: medium
Wallet   coins, purchases[]                         evidence: coin counter + "+"   confidence: high
Stars    rule unknown (guess: fewer hints = more stars)   confidence: guess
```

Relationships: Group 1-n Level, Level 1-n Entry, Level 1-1 Progress. All local;
no account or server seen (Play #3 is explicitly offline).

## Fixes from reviews (what to beat) — from ../reviews.csv, 1–3★

- Too many ads ("اعلان اعلان خلف اعلان", several reviews) → cap interstitials,
  rewarded-only for hints, never an ad mid-word.
- Wrong / sloppy clues and Quran verse typos → every clue checked by a human
  Arabic reader before release; in-app "report this clue".
- Levant-biased content, nothing about the Gulf → Gulf packs (geography, culture,
  football, food, dialect words).
- Hard-to-read font → Naskh-style font, large cells, Dynamic Type.
- Answers rejected / stuck levels → normalise أ إ آ ا, ة/ه, ى/ي; save progress per cell.
- Removed online challenge was missed ("تحدي وصله اونلاين") → later: daily puzzle + Game Center leaderboard.

## Feature matrix

See `features.csv`. Must: 14, should: 9, could: 5, skip: 3.

## Out of scope (cannot or should not be cloned)

- The originals' clue banks and photos — owned content. We write our own.
- Their names, logo, teal/yellow look and the "الجزء الثاني" sequel branding.
- Their cross-promotion network (Finjan's other games).
- Copyrighted photos for picture clues — use public-domain flags/maps or our own images.

## Size

Screens 8, flows 4, entities 5. Hard parts:
1. **Content**: ~1,500–3,000 accurate clues for launch (8 per level × 200–300 levels), reviewed by a native reader.
2. **Grid generation**: packing 6–10 Arabic words into a small connected grid with good crossings (offline generator script).
3. **Arabic text**: right-to-left layout, letter normalisation, isolated vs joined forms, a readable font.
Code: M (2–3 weeks). Content: the real schedule driver.
