#!/bin/zsh
# Records real Kalimat gameplay from the iPhone simulator for promo videos.
#   tools/promo/record.sh <out-dir> <level ids, comma separated>
# Writes <out-dir>/seg-NNN.mp4 (one per clue / celebration), segments.tsv and events.log.
set -e
HERE=${0:A:h}                                                   # this folder (before any cd)
OUT=${1:?out dir}; LEVELS=${2:?levels}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)                      # absolute: the script cds into the app
SIM=${SIM:-F8521F4E-66D7-4D0D-B4C7-E764AC22584A}      # iPhone 17 Pro simulator
APP=$(cd "$(dirname $0)/../../app" && pwd)
mkdir -p "$OUT"; : > "$OUT/events.log"
xcrun simctl boot $SIM 2>/dev/null || true
xcrun simctl status_bar $SIM override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
cd "$APP"
# build first so the recording isn't mostly a compile
xcodebuild build-for-testing -scheme Crossword -destination "id=$SIM" -derivedDataPath /tmp/claude-501/kalimat-dd -quiet
# Event-driven recording: watch_record.py records each clue (CLUE -> SOLVED) and each celebration
# (COMPLETE -> END) as its own file, so every video file is exactly one segment (see watch_record.py).
: > "$OUT/events.log"; rm -f "$OUT/done.flag"
WATCH_STOP_DELAY=2.0 python3 "$HERE/watch_record.py" $SIM "$OUT/events.log" "$OUT" "$OUT/done.flag" CLUE=SOLVED COMPLETE=END &
WATCH=$!
TEST_RUNNER_PROMO_LOG="$OUT/events.log" TEST_RUNNER_PROMO_LEVELS="$LEVELS" \
  xcodebuild test-without-building -scheme Crossword -destination "id=$SIM" -derivedDataPath /tmp/claude-501/kalimat-dd \
  -only-testing:CrosswordUITests/PromoRecording/testRecordPromoGameplay 2>&1 | grep -E "error:" | head -5 || true
touch "$OUT/done.flag"; wait $WATCH
echo "recorded: $OUT ($(wc -l < $OUT/segments.tsv | tr -d ' ') segments)"
