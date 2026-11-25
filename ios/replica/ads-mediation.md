# Ad mediation plan (2026-11-14)

**Decision: AdMob mediation with bidding at launch; move to AppLovin MAX at ~10–20k DAU.**

## Why
- Mediation makes several networks bid for each ad slot; the highest bid wins. More
  bidders = higher eCPM and fill. AdMob mediation is free and the simplest to start
  with; vendor blogs agree AdMob alone "leaves demand on the table" vs MAX/LevelPlay.
- AppLovin MAX dominates mediation for ad-heavy games in 2025–26 (AppLovin ~39–53% of
  iOS game ad revenue by different sources), but it's heavier to set up and its edge
  shows at scale. At launch DAU (hundreds) the difference is a few dollars.
- `AdService` is the only file that knows the ad SDK, so swapping AdMob → MAX later
  touches one file plus the adapters.

## Launch bidders (via AdMob mediation, iOS)
| network | why | AdMob doc |
| --- | --- | --- |
| AppLovin | largest iOS game demand | developers.google.com/admob/ios/mediation/applovin (bidding: rewarded, interstitial, native; not banner) |
| Mintegral | #2 iOS game network in 2026 benchmarks; strong rewarded | AdMob bidding partner since Jul 2025 |
| Pangle | described as strong for MENA audiences | developers.google.com/admob/ios/mediation/pangle (bidding needs a separate source per region: US, KR, ROW) |

Later candidates: Liftoff (Vungle), Unity Ads, Meta Audience Network, InMobi, Moloco.

## Costs of each extra network
- A separate account per network (human sign-up), its SDK (+ app size), its
  SKAdNetwork IDs in Info.plist (needed for iOS revenue), and its data in the App
  Privacy label. Add one at a time and watch eCPM in the AdMob mediation report.

## Rules that still apply (APP-STORE-REVIEW.md)
- Ads live in the first reviewed build — never flag-gated (⛔2, Ball 3D 5.6).
- UMP consent before any ad request; ATT prompt with no pre-screen (⛔1).
- Test only with Google test ad units / registered test devices (limited ad serving).
