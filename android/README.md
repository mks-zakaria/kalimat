# Kalimat for Android (كلمات)

The Android version of the iOS game in `../app`, written in Kotlin with Jetpack Compose.
Same puzzles, same rules, same look. The same seed gives the same letter bank and the same
word-search grid on both platforms.

## Build and run

Open the `android/` folder in Android Studio and press Run, or from a terminal:

```sh
cd android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"   # Android Studio's JDK
./gradlew :app:installDebug          # build and install on the running emulator / phone
./gradlew :app:testDebugUnitTest     # 41 unit tests (game rules, save file, IQ, parity with iOS)
```

Debug builds only show Google's **test** ads.

## Where things are

```
app/src/main/java/com/zakaria/crossword/
├── MainActivity.kt        start-up: loads packs, save file, sounds, ads; RTL; fixed font size
├── AppState.kt            what every screen needs (packs + progress store), via LocalApp
├── AppLinks.kt            privacy / terms / support pages
├── model/                 Pack, Level, Entry, CellPos, LevelProgress, GameMode
├── data/                  ContentStore (reads the pack JSON), ProgressStore (the save file)
├── game/                  the rules, no UI:
│   ├── GameEngine.kt          crossword: letter bank, checking, hints, stars
│   ├── WordSearch*.kt         regrouping clues, building the letter square, finding words
│   ├── IQ.kt                  the speed score
│   ├── SeededRng.kt           random numbers identical to the iOS app's
│   └── ArabicText.kt          normalising answers, decoy letters
├── sound/Sounds.kt        sounds + vibration
├── ads/                   AdMob + consent (Ads.kt), Play rating card (Review.kt)
└── ui/
    ├── theme/             colours, sizes, the Arabic font, arNum() for ٠١٢ digits
    ├── components/        tiles, buttons, board, slots, keys, scene, dialogs…
    ├── navigation/        the back stack (Navigator) and which screen shows (AppNavHost)
    ├── screens/           Home, Packs, Levels, Board (crossword), WordSearch, LevelComplete
    ├── iq/                solve timer, IQ box, IQ button, IQ card
    └── coins/             coins card, not-enough-coins card
```

Each Kotlin file starts with a comment saying what it is for, and most follow the Swift file
of the same name in `../app/Sources`.

## Shared with iOS (not copied)

`app/build.gradle.kts` reads these straight from the iOS folders:

- `../app/Resources/Packs/*.json`: the puzzles
- `../app/Resources/Fonts/NotoNaskhArabic.ttf`: the font
- `../app/Resources/Sounds/*.wav`: the sounds

`app/src/test/resources/wordsearch-ios.json` was exported by the iOS code
(`app/tools/export_wordsearch.swift`). `WordSearchTest` checks that every Android grid matches it.
**After changing the packs or the word-search code, export it again**, or the test fails:

```sh
cd app && swiftc -O -parse-as-library tools/export_wordsearch.swift Sources/Models/Content.swift \
  Sources/Game/*.swift -o /tmp/wsexport && /tmp/wsexport Resources/Packs ../android/app/src/test/resources/wordsearch-ios.json
```

## Before the first Google Play release

1. **AdMob:** add an Android app in AdMob (same account, publisher `pub-4306191597700064`),
   create a *rewarded* unit and an *interstitial* unit, and put the three ids in
   `gradle.properties` (`kalimat.admob.*`). A release build stops with an error until they're filled in.
   Also add the Android app to the existing GDPR consent message.
2. **Signing:** create an upload key, add a `signingConfigs` block for it (keep the passwords
   out of git), then run `./gradlew :app:bundleRelease` and upload the `.aab`.
   Turn on Play App Signing.
3. **Play Console:** privacy policy URL `https://kalimat-web.vercel.app/privacy.html`. In Data
   safety, declare the advertising ID and the data the AdMob SDK collects. Set the content
   rating, mark the app as containing ads, and use `store/icon-512.png` as the app icon.
4. Lint suggests newer library versions and dropping the portrait lock (Android 16 ignores it
   on tablets). Neither blocks a phone release.
