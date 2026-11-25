# Bugs

| ID | sev | title | status |
| --- | --- | --- | --- |
| B01 | S3 | Coin counter looks like a light/dark switch and does nothing | fixed — now a button that opens the coins screen (S07); test `testCoinButtonOpensCoinsScreen` |
| B02 | S3 | Tapping a locked level or pack only plays a sound — no explanation | fixed — toast explains how to unlock; test `testLockedLevelShowsMessage` |
| B03 | S4 | A letter removed by the hint stays in the VoiceOver tree as an invisible disabled button | fixed — hidden from accessibility; test `testRemoveHintCostsCoins` |

## B01 — coin counter is a dead control
- **Steps:** open the app → tap the dark pill with the gold coin at the top left.
- **Expected:** something happens (it looks like a control).
- **Actual:** nothing. A pill with a round knob reads as a toggle (reported by the user as "light/dark").
- **Evidence:** user report, 2026-11-14.

## B02 — locked items give no feedback
- **Steps:** Levels → tap a locked medallion.
- **Expected:** told why it is locked.
- **Actual:** only the "wrong" sound.

## B03 — removed key still exposed to accessibility
- **Steps:** Board → "حذف حرف" → count key buttons (UI test).
- **Expected:** 11 keys. **Actual:** 12 (one invisible, disabled).
| B04 | S4 | Empty answer slots are exposed as buttons but do nothing (found by the dead-control audit) | fixed — only typed slots carry the button trait |
| B05 | S2 | Words with ئ ؤ ى أ إ آ shown misspelled (زئير as زيير) because the game folded letter forms | fixed — exact spelling kept in grid and keys; folding only for duplicate detection; engine_check asserts زئير |
