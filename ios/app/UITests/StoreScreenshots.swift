import XCTest

/// App Store screenshots: plays real screens from a demo save and attaches raw captures named
/// 1-home … 6-packs. Skipped in normal runs; enable with
///   TEST_RUNNER_STORE_SHOTS=1 xcodebuild test … -only-testing:CrosswordUITests/StoreScreenshots
/// then tools/make_store_shots.swift frames them with captions.
final class StoreScreenshots: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SHOTS"] != nil, "store screenshots only")
        continueAfterFailure = false
    }

    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-reset", "-uitest", "-demo"] + extra
        app.launch()
        return app
    }

    func shot(_ app: XCUIApplication, _ name: String) {
        let image = app.screenshot()
        let a = XCTAttachment(screenshot: image)
        a.name = name; a.lifetime = .keepAlways; add(a)
        // Also as files when asked (simulator only): one folder per device for the store sets.
        if let dir = ProcessInfo.processInfo.environment["KALIMAT_SHOTS_DIR"] {
            try? image.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    func packs() -> [Pack] {
        (Bundle(for: Self.self).urls(forResourcesWithExtension: "json", subdirectory: "Packs") ?? [])
            .sorted { $0.path < $1.path }
            .map { try! JSONDecoder().decode(Pack.self, from: Data(contentsOf: $0)) }
            .sorted { $0.order < $1.order }
    }

    /// Types `count` letters (nil = all) of the word whose clue is on screen.
    func type(_ app: XCUIApplication, _ level: Level, count: Int? = nil) {
        guard let e = level.entries.first(where: { app.staticTexts[$0.clueAr].exists }) else { return XCTFail("no clue on screen") }
        let letters = e.answer.map(String.init)
        for (i, letter) in letters.prefix(count ?? letters.count).enumerated() {
            let slot = app.descendants(matching: .any)["slot.\(i)"]
            guard slot.waitForExistence(timeout: 2), slot.label == "فارغ" else { continue }
            let key = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'key.' AND label == %@ AND isEnabled == true", letter)).firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 2)); key.tap()
        }
    }

    func testStoreScreenshots() {
        let all = packs()
        let crossword = all[0].levels[5]                                     // p01-006, next after the demo save
        let ws = WordSearchContent.packs(from: all)[0].levels[3]             // p01-w004
        let puzzle = WordSearchGenerator.make(level: ws)

        // 1 home
        var app = launch()
        XCTAssertTrue(app.buttons["home.iq"].waitForExistence(timeout: 5))
        sleep(2); shot(app, "1-home")

        // 2 crossword, mid-solve
        app.buttons["home.play"].tap()
        XCTAssertTrue(app.buttons["hint.reveal"].waitForExistence(timeout: 5))
        type(app, crossword); sleep(1)
        type(app, crossword); sleep(1)
        type(app, crossword, count: 2); sleep(1)
        shot(app, "2-crossword")

        // 3 word search, a few words found
        app = launch(["-screen", "level", "-level", ws.id])
        XCTAssertTrue(app.otherElements["ws.grid"].waitForExistence(timeout: 5))
        func find(_ e: Entry) {
            let cells = puzzle.placements[e.id]!.cells
            app.staticTexts["ws.cell.\(cells.first!.row).\(cells.first!.col)"]
                .press(forDuration: 0.1, thenDragTo: app.staticTexts["ws.cell.\(cells.last!.row).\(cells.last!.col)"])
        }
        // pace like a quick human player so the IQ shown is believable (not the 160 cap)
        for e in ws.entries.prefix(3) { find(e); sleep(5) }
        app.buttons["ws.clue.4"].tap()
        sleep(1); shot(app, "3-wordsearch")

        // 4 level complete with the IQ change
        for e in ws.entries.dropFirst(3) { sleep(5); find(e) }
        XCTAssertTrue(app.buttons["complete.next"].waitForExistence(timeout: 5))
        sleep(5); shot(app, "4-complete")

        // 5 the IQ card
        app.buttons["iq.level"].tap()
        XCTAssertTrue(app.otherElements["iq.card"].waitForExistence(timeout: 3))
        sleep(1); shot(app, "5-iq")

        // 6 packs, word-search mode
        app = launch(["-screen", "packs"])
        XCTAssertTrue(app.buttons["mode.wordsearch"].waitForExistence(timeout: 5))
        sleep(1); shot(app, "6-packs")
    }
}
