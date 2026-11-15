# Kalimat (كلمات متقاطعة: ألغاز وذكاء) — App Store submission

_Bundle `com.zakaria.crossword` (registered 2026-11-15, id `893BVALTMP`) · Team `JF83ACY9N9` ·
v1.0.0 (1) · iOS 18+ · iPhone only · primary language Arabic (ar-SA), English listing too._

## Status

| Item | State |
|------|-------|
| APP-STORE-REVIEW.md walked against the code | ✅ 2026-11-15 — see "Checklist pass" below |
| Website (privacy, terms, support) | ✅ live on https://kalimat-web.vercel.app (all 200) |
| Privacy-policy link inside the app | ✅ coins screen (reachable from every screen): الخصوصية · الشروط · الدعم |
| Privacy manifest `Resources/PrivacyInfo.xcprivacy` | ✅ bundled; app code collects nothing, no required-reason APIs |
| Screenshots 6.9" (1320×2868, RGB, no alpha) | ✅ 5 in `store/screenshots-ar/` (raw captures in `store/raw/`) |
| Listing text ar-SA + en-US (`listing.json`) | ✅ all fields within limits (NFC code points), no keyword repeats name/subtitle |
| App icon 1024², no alpha | ✅ |
| Rating prompt | ✅ 8th / 30th / 80th finished level, once per version |
| Real AdMob app + ad units | ✅ app `ca-app-pub-4306191597700064~4043802655`; rewarded-coins `/6791199584`, between-levels `/4339316123` (release builds only; debug keeps Google demo units) |
| GDPR / US-states message in AdMob Privacy & messaging (no IDFA explainer) | ⏳ owner, in the AdMob console |
| `app-ads.txt` on https://kalimat-web.vercel.app/app-ads.txt | ✅ `google.com, pub-4306191597700064, DIRECT, f08c47fec0942fa0` |
| **App record in App Store Connect** | ⏳ needs Chrome (no API for creating apps) |
| **App Privacy questionnaire + Publish** | ⏳ needs Chrome (no API) |
| Release archive + upload | ⏳ after the real ad ids are in |
| Submit for review | ⛔ only with the owner's explicit go |

## Regenerate

```sh
# raw captures (iPhone 17 Pro Max simulator, status bar 9:41)
TEST_RUNNER_STORE_SHOTS=1 xcodebuild test -project app/Crossword.xcodeproj -scheme Crossword \
  -destination "name=Kalimat-ProMax" -only-testing:CrosswordUITests/StoreScreenshots
# frames with captions
swiftc -parse-as-library app/tools/make_store_shots.swift app/Sources/Design/*.swift app/Sources/Game/ArabicText.swift -o /tmp/shots
/tmp/shots app/Resources/Fonts/NotoNaskhArabic.ttf store/raw store/screenshots-ar
```

## Checklist pass (APP-STORE-REVIEW.md, 2026-11-15)

- **⛔1 permissions.** Only one prompt: App Tracking Transparency, fired 2.5 s after the first
  finished level, no screen of ours before it. Purpose string says what it is for and that the
  game works either way; it does not tell the player how to answer. Google UMP: the AdMob
  account must publish **GDPR (and US states) messages only — no "IDFA explainer"** (the demo
  one says "Tap Allow on the next screen"). No other purpose strings declared.
- **⛔2 dormant features.** Nothing switched off by a flag. Removed the leftovers of the
  never-built "remove ads" purchase (`adsRemoved` argument, `processedTransactions` field).
  Debug-only code (`-uitest`, `-screen`, `-demo`, `-reset`) is inside `#if DEBUG` and absent from
  release builds. The design catalog is excluded from the target. Review notes describe every
  feature, including ads.
- **§3 hygiene.** Bundle id real; `UIDeviceFamily` = 1 in the built Info.plist;
  `ITSAppUsesNonExemptEncryption` = NO (HTTPS only, via the OS and the ad SDK); version 1.0.0 (1).
- **⛔4 iPad.** Ran on the iPad Air 11" (M3) simulator in iPhone compatibility mode: home, crossword,
  word search and packs all fit with every button visible.
- **§5 reviewer basics.** No login; every screen reachable; privacy policy live; App Privacy answers
  below match the code (our code collects nothing; Google Mobile Ads does).
- **§6 launch quality.** Listings in Arabic (the app's only UI language) and English; rating prompt
  in; App Store ID to be wired into the website once the record exists; contact email on the
  support page = makhkhas.zakaria@gmail.com, use the same in App Store Connect.

## App Review notes (paste into "Notes")

> Kalimat is an Arabic word game with two modes: crosswords (tap letters to fill each clue's word)
> and word search (draw a straight line over the hidden word in a letter grid). 250 puzzles in 8
> packs, all bundled; the game works offline and has no accounts or login.
>
> Coins are earned by finishing puzzles and spent on hints (reveal a letter, remove a wrong letter,
> reveal a hidden word, or mark its first letter). Coins cannot be bought; there are no in-app
> purchases.
>
> Ads (Google AdMob): a rewarded video the player chooses to watch for 50 coins (coins screen, or
> the card shown when out of coins), and an occasional interstitial between levels — never before
> level 4, at most once every 3 levels and 3 minutes. In the EEA/UK Google's consent form appears
> on first launch. The App Tracking Transparency prompt appears once, after the first finished
> level; the game works fully whichever answer is chosen.
>
> "IQ" is a game score based on solving speed, explained in-app (tap the IQ button on the home
> screen) and labelled there as an estimate for fun, not a scientific IQ test.
>
> Privacy policy, terms and support links are on the coins screen (tap the coin counter at the top
> of any screen).

## App Privacy answers (App Store Connect › App Privacy) — what Google Mobile Ads collects

Our own code collects nothing. Declare the ad SDK's collection:

| Data type | Linked to user | Used for tracking | Purposes |
|---|---|---|---|
| Identifiers › Device ID (IDFA, only with ATT permission) | No | **Yes** | Third-party advertising |
| Usage Data › Advertising Data | No | **Yes** | Third-party advertising, Analytics |
| Usage Data › Product Interaction | No | No | Analytics |
| Location › Coarse Location (from IP) | No | No | Third-party advertising |
| Diagnostics › Crash Data, Performance Data | No | No | Analytics |

Then press **Publish** at the top of the App Privacy page (saving only stores a draft).

## Other App Store Connect fields

- Category: Games › Word (secondary Games › Puzzle). Price: free. Availability: all territories.
- Age rating: no objectionable content; ads present. Expected 4+.
- Copyright: 2026 Zakaria Makhkhas. Content rights: no third-party content (font under SIL OFL).
- Review contact: name, **phone**, email — owner to provide.
