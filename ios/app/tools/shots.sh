#!/bin/zsh
# Build for the iPhone 11 simulator and screenshot each screen into $1 (debug launch args).
set -e
SIM=$(xcrun simctl list devices | grep "Crossword-iPhone11" | grep -oE "[0-9A-F-]{36}" | head -1)
OUT=${1:-../replica/clone-screens}
mkdir -p $OUT
xcrun simctl boot $SIM 2>/dev/null || true
xcodebuild -project Crossword.xcodeproj -scheme Crossword -destination "id=$SIM" -configuration Debug -derivedDataPath build build > build-sim.log 2>&1 || { grep error: build-sim.log | head; exit 1; }
xcrun simctl install $SIM build/Build/Products/Debug-iphonesimulator/Crossword.app
for s in home packs levels board; do
  xcrun simctl terminate $SIM com.zakaria.crossword 2>/dev/null || true
  if [ $s = home ]; then xcrun simctl launch $SIM com.zakaria.crossword >/dev/null
  else xcrun simctl launch $SIM com.zakaria.crossword -screen $s >/dev/null; fi
  sleep 2.5
  xcrun simctl io $SIM screenshot $OUT/$s.png >/dev/null 2>&1
done
cd $OUT && magick home.png packs.png levels.png board.png -resize x900 +append sheet.png && echo "$OUT/sheet.png"
