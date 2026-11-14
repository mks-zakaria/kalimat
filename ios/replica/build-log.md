# Build log

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| tools | 2026-11-14 | done | real clue sheet (12 draft clues, none reviewed) | — |
| engine | 2026-11-14 | done | hints, stars, saving progress | — logic check `app/tools/engine_check.swift` passes on 3 levels |
| S04 board | 2026-11-14 | partial (M0) | stars header, hint-revealed state wiring, save | cell sizing for 3×3 to 9×9 grids |
| S05 clue | 2026-11-14 | partial (M0) | hint buttons, coins, share, picture clues | — |
| device run | 2026-11-14 | blocked | Xcode 26.6 has the iOS 26.5 SDK but not the iOS 26.5 platform component, so xcodebuild finds no destinations | needs `xcodebuild -downloadPlatform iOS` (multi-GB), user approval pending |
| S01 home | 2026-11-14 | done | — | — |
| S02 packs / S03 levels | 2026-11-14 | done | — | unlock rules decided here (sequential levels, pack after previous pack) |
| S04 + S06 | 2026-11-14 | done (M1) | iCloud sync (M3) | restoring an engine from saved progress without losing the save callback |
| S05 hints + coins | 2026-11-14 | done (M1) | rewarded ad for coins, S07 store (M2) | keeping removed decoys removed after a reveal rebuilds the bank |
| checks | 2026-11-14 | — | — | `swiftc -typecheck -sdk iphoneos` compiles the app without the missing platform component |
| sounds | 2026-11-14 | done | — | 11 original sounds synthesised by tools/make_sounds.py (stdlib, licence-free); ambient session respects the silent switch; mute toggle on S01; haptics paired with each sound |
| design v2 | 2026-11-14 | done | — | user: "too simple". Desert scenes per pack (drawn in code), 3D tiles, game buttons, emblem logo, winding level path, single-screen play (board + clue dock, auto-advance), celebration overlay with confetti + coin reward (+5 / +10 for 3 stars, first completion only). 36/36 contrast pairs AA. Debug-only `-screen` launch arg + tools/shots.sh for simulator screenshots |
| content v1 | 2026-11-14 | done (unreviewed) | native review of all clues; picture clues | 6 parallel writers, 886 rows → 814 unique (78 cross-file duplicate answers skipped). Round-robin generator: 135 levels, 8 packs × 16–17, 808/814 clues used, max grid 8×9. All packs pass engine_check. Every clue still needs `reviewed_by` before a release build |
| sound everywhere | 2026-11-14 | done | — | SoundButton + CoinButton in every top bar (TopBarActions); test testSoundToggleOnEveryScreen |
| app icon | 2026-11-14 | done | dark / tinted variants (iOS 18) | rendered from game components by tools/render_icon.swift (1024², no alpha). First try (كلمات, 5 tiles) unreadable at 60 px → لغز / لعب, 3 big tiles |
| UI tests | 2026-11-14 | done | — | XCUITest target, 9 flow tests + dead-control audit (tools/test.sh). Bugs B01–B03 fixed |
| ads (test IDs) | 2026-11-14 | done (test IDs) | real App ID + ad units; mediation bidders; Remove-ads IAP | GoogleMobileAds 12 (bundles UMP 3). Rewarded on S07 + offered when out of coins; interstitial between levels (≥3 levels & ≥180 s, never before level 4); ATT after first finished level. Google's demo App ID shows an "IDFA explainer" UMP message that says "Tap Allow" — violates ⛔1; added to APP-STORE-REVIEW.md: real App ID must not publish it. AdsSmokeTest proves a demo rewarded ad shows |
