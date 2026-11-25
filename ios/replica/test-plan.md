# Test plan — Arabic crossword (iOS)

Automated with XCUITest (`app/UITests/`) on the `Crossword-iPhone11` simulator:

```bash
cd app && ./tools/test.sh            # all UI tests + the dead-control audit
```

Debug-only launch arguments (compiled out of release builds): `-reset` (fresh save),
`-screen home|packs|levels|board|level`, `-level <id>`.

| ID | flow | case | automated |
| --- | --- | --- | --- |
| F01-H1 | solve a level | type every word from the keys → celebration → coins +10 (3★, no hints) | `testSolveFirstLevelEndToEnd` |
| F01-E1 | solve a level | wrong word → shake, slots clear, no coins lost | `testWrongAnswerClearsSlots` |
| F01-E2 | solve a level | quit mid-level → relaunch → earned letters still on the board | `testProgressSurvivesRelaunch` |
| F01-E3 | solve a level | tap a typed letter → it goes back to the keys | `testTapSlotReturnsLetter` |
| F01-E4 | solve a level | replay a finished level → no second coin reward | manual |
| F01-E5 | solve a level | largest grid (8×9) fits with the dock, no scrolling | screenshot (tools/shots.sh) |
| F02-H1 | hint | reveal letter → −20 coins, letter shown in turquoise | `testRevealHintCostsCoins` |
| F02-H2 | hint | remove letter → −10 coins, one decoy key gone | `testRemoveHintCostsCoins` |
| F02-N1 | hint | not enough coins → message, no change | manual (needs ≤ 9 coins) |
| F03-H1 | coins | tap the coin counter → coins screen with balance and how to earn | `testCoinButtonOpensCoinsScreen` |
| F05-N1 | navigation | tap a locked level → message explains how to unlock | `testLockedLevelShowsMessage` |
| F05-N2 | navigation | tap a locked pack → message | covered by the audit |
| F05-H1 | navigation | back button returns one screen | covered by the audit |
| A01 | every screen | **dead-control audit**: tap every hittable button; the screen must change | `testDeadControlAudit` |
| M01 | sound | every action plays its sound, silent switch respected | manual on device |
| M02 | iPad | runs in iPhone compatibility mode on iPad Air 11" M3, dock fully visible | manual (APP-STORE-REVIEW.md ⛔4) |
