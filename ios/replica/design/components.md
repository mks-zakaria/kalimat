# Components

Tokens: `tokens.json` → `app/Sources/Design/Theme.swift`. Views use `Theme.*`,
never raw hex. Whole app runs `.environment(\.layoutDirection, .rightToLeft)`.
All copy below is ours, written fresh. Icons: SF Symbols (Apple, free for
apps on Apple platforms) — no icons, art or sounds from the reference apps.

```
GridCell
  variants  letter, block (no cell drawn, bg shows through)
  states    empty (cell), active-word (cell-active), hint-revealed (cell-hint),
            solved (cell-solved / on-cell-solved), wrong flash (danger border 2px, 220ms)
  size      fits board: min(cell-max 40, (width - gaps) / columns); gap 3; radius cell 6
  tokens    font cell 22/700 Naskh, text cell-text
  a11y      board is one accessibility element per WORD, not per cell:
            "الكلمة ٣، أفقي، ٤ أحرف، محلولة"; double-tap opens the clue
  used on   S04 board, S05 (mini preview)

CrosswordBoard
  layout    columns right→left (col 0 = rightmost); centred; scales to width
  states    idle, word selected (its cells cell-active), complete (all solved → celebrate)
  used on   S04

ClueCard
  variants  text, picture (image 16:10, radius card), category header
  states    default; share button top-leading
  tokens    surface, radius card 16, shadow card, clue 22/600, caption for category (text-muted)
  a11y      clue read first; image has a written label from the sheet
  used on   S05

AnswerSlots
  states    empty (surface + border-input 1.5), typed (text), revealed (cell-hint),
            wrong (danger flash + shake), solved (cell-solved)
  size      slot 44, gap 6; shrinks to 36 for 9 letters
  a11y      announces "٣ من ٥ أحرف"
  used on   S05

LetterKey / LetterBank
  states    normal (key/key-text), used (key-used/key-used-text, still tappable to undo),
            removed by hint (hidden, space kept), pressed (scale .94)
  size      key 46 ≥ hit-min 44; radius key 10; shadow key; 2 rows, wraps
  a11y      each key a button with its letter name; haptic light on tap
  used on   S05

HintButton
  variants  reveal letter (eye icon, cost 20), remove letter (eraser icon, cost 10)
  states    enabled, not-enough-coins (opens S07), disabled (nothing left to remove)
  tokens    surface, accent text, coin chip with cost
  used on   S05

CoinBadge
  states    default, +N earn animation, -N spend animation
  tokens    coin / on-coin, pill; "+" button opens S07
  used on   S03 S04 S05 S07

TopBar
  parts     back (chevron.forward in RTL), title, trailing slot (CoinBadge or stars)
  size      topbar 52
  used on   S02–S07

LevelTile
  states    locked (lock icon, text-muted, not tappable), open (accent border),
            solved (0–3 stars, cell-solved fill)
  used on   S03

PackCard
  states    locked (needs N stars), open (progress bar x/y), complete
  used on   S02

PrimaryButton
  variants  primary (accent / on-accent), secondary (surface / accent, border)
  states    default, pressed, disabled (40% opacity), loading (spinner, label kept)
  size      48 high, radius pill
  used on   S01 S06 S07

StarsView
  0–3 stars, star.fill coin colour, empty star border-input
  used on   S03 S06
```
