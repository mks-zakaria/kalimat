import XCTest

/// Plays real levels at a human pace while `tools/promo/record.sh` records the simulator screen, and logs
/// when each clue appears / is solved so `tools/promo/make_videos.py` can cut it into short videos.
/// Skipped in normal runs; enabled with TEST_RUNNER_PROMO_LOG=<file>.
/// Log lines: `<epoch seconds> <EVENT> <level id> <entry id> <answer> | <clue>`.
final class PromoRecording: XCTestCase {

    private var logURL: URL!

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["PROMO_LOG"]
        try XCTSkipUnless(path != nil, "promo recording only")
        logURL = URL(fileURLWithPath: path!)
        continueAfterFailure = true
    }

    private func log(_ event: String, _ level: String, _ entry: String = "-", _ answer: String = "-", _ clue: String = "") {
        let line = String(format: "%.3f", Date().timeIntervalSince1970) + " \(event) \(level) \(entry) \(answer) | \(clue)\n"
        if let h = try? FileHandle(forWritingTo: logURL) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
        else { try? line.write(to: logURL, atomically: true, encoding: .utf8) }
    }

    private func packs() -> [Pack] {
        (Bundle(for: Self.self).urls(forResourcesWithExtension: "json", subdirectory: "Packs") ?? [])
            .map { try! JSONDecoder().decode(Pack.self, from: Data(contentsOf: $0)) }
            .sorted { $0.order < $1.order }
    }

    private func launch(_ level: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-reset", "-uitest", "-screen", "level", "-level", level]
        app.launch()
        return app
    }

    /// Crossword: for each clue, a reading pause (the "can you solve it?" beat), then typing at human speed.
    private func playCrossword(_ level: Level) {
        let app = launch(level.id)
        guard app.buttons["hint.reveal"].waitForExistence(timeout: 8) else { return XCTFail("board \(level.id)") }
        sleep(1)
        log("LEVEL", level.id)
        for _ in level.entries {
            if app.buttons["complete.next"].exists { break }
            guard let e = level.entries.first(where: { app.staticTexts[$0.clueAr].exists }) else { break }
            log("CLUE", level.id, e.id, e.answer, e.clueAr)
            usleep(3_200_000)                                   // time to read and think
            log("TYPE", level.id, e.id, e.answer)
            for (i, letter) in e.answer.map(String.init).enumerated() {
                let slot = app.descendants(matching: .any)["slot.\(i)"]
                guard slot.waitForExistence(timeout: 2), slot.label == "فارغ" else { continue }
                let key = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'key.' AND label == %@ AND isEnabled == true", letter)).firstMatch
                if key.waitForExistence(timeout: 2) { key.tap() }
                usleep(250_000)
            }
            log("SOLVED", level.id, e.id, e.answer)
            usleep(1_300_000)                                   // auto-advance animation
        }
        if app.buttons["complete.next"].waitForExistence(timeout: 6) { log("COMPLETE", level.id) }
        sleep(5)                                                // celebration + IQ change
        log("END", level.id)
    }

    /// Word search: read the clue, then drag over the word.
    private func playWordSearch(_ level: Level) {
        let puzzle = WordSearchGenerator.make(level: level)
        let app = launch(level.id)
        guard app.otherElements["ws.grid"].waitForExistence(timeout: 8) else { return XCTFail("grid \(level.id)") }
        sleep(1)
        log("LEVEL", level.id)
        for e in level.entries {
            guard let cells = puzzle.placements[e.id]?.cells, let a = cells.first, let b = cells.last else { continue }
            log("CLUE", level.id, e.id, e.answer, e.clueAr)
            usleep(3_000_000)                                   // read the clue (and let the recorder start)
            app.staticTexts["ws.cell.\(a.row).\(a.col)"]
                .press(forDuration: 0.15, thenDragTo: app.staticTexts["ws.cell.\(b.row).\(b.col)"])
            log("SOLVED", level.id, e.id, e.answer)
            usleep(900_000)
        }
        if app.buttons["complete.next"].waitForExistence(timeout: 6) { log("COMPLETE", level.id) }
        sleep(5)
        log("END", level.id)
    }

    func testRecordPromoGameplay() {
        let all = packs()
        let ids = (ProcessInfo.processInfo.environment["PROMO_LEVELS"] ?? "").split(separator: ",").map(String.init)
        let ws = WordSearchContent.packs(from: all)
        let levels = (all + ws).flatMap { $0.levels }
        for id in ids {
            guard let l = levels.first(where: { $0.id == id }) else { XCTFail("no level \(id)"); continue }
            if id.contains("-w") { playWordSearch(l) } else { playCrossword(l) }
        }
    }
}
