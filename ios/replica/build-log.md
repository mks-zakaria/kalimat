# Build log

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| tools | 2026-11-14 | done | real clue sheet (12 draft clues, none reviewed) | — |
| engine | 2026-11-14 | done | hints, stars, saving progress | — logic check `app/tools/engine_check.swift` passes on 3 levels |
| S04 board | 2026-11-14 | partial (M0) | stars header, hint-revealed state wiring, save | cell sizing for 3×3 to 9×9 grids |
| S05 clue | 2026-11-14 | partial (M0) | hint buttons, coins, share, picture clues | — |
| device run | 2026-11-14 | blocked | Xcode 26.6 has the iOS 26.5 SDK but not the iOS 26.5 platform component, so xcodebuild finds no destinations | needs `xcodebuild -downloadPlatform iOS` (multi-GB), user approval pending |
