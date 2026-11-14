#!/bin/zsh
# Runs every UI test (incl. the dead-control audit) on the iPhone 11 simulator.
#   ./tools/test.sh                       all tests
#   ./tools/test.sh DeadControlAudit      one class
SIM=$(xcrun simctl list devices | grep "Crossword-iPhone11" | grep -oE "[0-9A-F-]{36}" | head -1)
ONLY=${1:+-only-testing:CrosswordUITests/$1}
rm -rf build/TestResults.xcresult
xcodebuild test -project Crossword.xcodeproj -scheme Crossword -destination "id=$SIM" \
  -derivedDataPath build -resultBundlePath build/TestResults.xcresult $ONLY > build/test.log 2>&1
grep -E "Test Case .* (passed|failed)|error: -|Executed" build/test.log | sed -E 's/^.*Test Case //' | tail -40
sed -n "/AUDIT-REPORT/,/AUDIT-END/p" build/test.log | grep -v AUDIT || true
# pass only if the overall total (the last "Executed" line) has no failures
grep -E "Executed [0-9]+ tests?, with" build/test.log | tail -1 | grep -q "with 0 failures"
