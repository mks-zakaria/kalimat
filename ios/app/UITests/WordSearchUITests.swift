import XCTest

/// Word-search mode (S08): draw or tap a straight line over each hidden answer.
/// The test target compiles the game logic, so it knows where the app hid each word.
final class WordSearchUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-reset", "-uitest"] + args
        app.launch()
        return app
    }

    func wsLevel(_ id: String) -> Level {
        let bundle = Bundle(for: Self.self)
        let packs = (bundle.urls(forResourcesWithExtension: "json", subdirectory: "Packs") ?? [])
            .sorted { $0.path < $1.path }
            .map { try! JSONDecoder().decode(Pack.self, from: Data(contentsOf: $0)) }
        let ws = WordSearchContent.packs(from: packs).flatMap(\.levels)
        return ws.first { $0.id == id }!
    }

    func cell(_ app: XCUIApplication, _ c: CellPos) -> XCUIElement {
        app.staticTexts["ws.cell.\(c.row).\(c.col)"]
    }

    func coins(_ app: XCUIApplication) -> String { app.buttons["coins.button"].label }

    func doneCount(_ app: XCUIApplication, _ n: Int) -> Int {
        (0..<n).filter { (app.buttons["ws.clue.\($0)"].value as? String) == "تم" }.count
    }

    func testSolveWordSearchByTapAndDrag() {
        let app = launch(["-screen", "level", "-level", "p01-w001"])
        let level = wsLevel("p01-w001")
        let puzzle = WordSearchGenerator.make(level: level)
        XCTAssertTrue(app.otherElements["ws.grid"].waitForExistence(timeout: 5))
        let before = coins(app)

        for (i, e) in level.entries.enumerated() {
            if app.buttons["complete.next"].exists { break }
            let cells = puzzle.placements[e.id]!.cells
            let a = cell(app, cells.first!), b = cell(app, cells.last!)
            if i % 2 == 0 {
                a.press(forDuration: 0.1, thenDragTo: b)        // draw the line
            } else {
                b.tap(); a.tap()                                  // tap last then first (backwards)
            }
            if i < level.entries.count - 1 {
                XCTAssertTrue(app.buttons["ws.clue.\(i)"].waitForExistence(timeout: 2))
                let marked = NSPredicate(format: "value == %@", "تم")
                expectation(for: marked, evaluatedWith: app.buttons["ws.clue.\(i)"])
                waitForExpectations(timeout: 3)
            }
        }
        XCTAssertTrue(app.buttons["complete.next"].waitForExistence(timeout: 5), "level complete overlay")
        sleep(1)
        XCTAssertNotEqual(coins(app), before, "3-star reward paid")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ws-complete"; shot.lifetime = .keepAlways; add(shot)
    }

    func testWrongLineMarksNothing() {
        let app = launch(["-screen", "level", "-level", "p01-w001"])
        let level = wsLevel("p01-w001")
        let puzzle = WordSearchGenerator.make(level: level)
        XCTAssertTrue(app.otherElements["ws.grid"].waitForExistence(timeout: 5))
        // a 3-cell line along the top row that spells no answer either way
        let answers = Set(level.entries.flatMap { e -> [[String]] in
            let l = WordSearchGenerator.letters(e); return [l, l.reversed()]
        })
        let start = (0..<puzzle.size - 2).first { c in
            !answers.contains((0..<3).map { puzzle.letter(CellPos(row: 0, col: c + $0)) })
        }!
        cell(app, CellPos(row: 0, col: start)).press(forDuration: 0.1, thenDragTo: cell(app, CellPos(row: 0, col: start + 2)))
        sleep(1)
        XCTAssertEqual(doneCount(app, level.entries.count), 0)
        XCTAssertFalse(app.buttons["complete.next"].exists)
    }

    func testHintsCostCoinsAndShowHelp() {
        let app = launch(["-screen", "level", "-level", "p01-w001"])
        let level = wsLevel("p01-w001")
        XCTAssertTrue(app.buttons["ws.hint.word"].waitForExistence(timeout: 5))
        XCTAssertTrue(coins(app).contains("١٠٠"))
        app.buttons["ws.hint.word"].tap()
        XCTAssertTrue(app.staticTexts[level.entries[0].answer].waitForExistence(timeout: 2), "answer shown under its clue")
        XCTAssertTrue(coins(app).contains("٨٠"), coins(app))
        XCTAssertFalse(app.buttons["ws.hint.word"].isEnabled, "same word cannot be bought twice")
        app.buttons["ws.hint.start"].tap()
        XCTAssertTrue(coins(app).contains("٧٠"), coins(app))
        // pick another clue: the word hint is available again for it
        app.buttons["ws.clue.1"].tap()
        XCTAssertTrue(app.buttons["ws.hint.word"].isEnabled)
    }

    func testHomeAndPacksReachWordSearch() {
        let app = launch([])
        app.buttons["home.wordsearch"].tap()
        XCTAssertTrue(app.otherElements["ws.grid"].waitForExistence(timeout: 5), "home opens the next word search")
        app.buttons["nav.back"].tap()
        app.buttons["home.packs"].tap()
        XCTAssertTrue(app.buttons["pack.p01"].waitForExistence(timeout: 3))
        app.buttons["mode.wordsearch"].tap()
        XCTAssertTrue(app.buttons["pack.ws-p01"].waitForExistence(timeout: 3))
        app.buttons["pack.ws-p01"].tap()
        XCTAssertTrue(app.buttons["level.p01-w001"].waitForExistence(timeout: 3))
        app.buttons["level.p01-w001"].tap()
        XCTAssertTrue(app.otherElements["ws.grid"].waitForExistence(timeout: 5))
    }
}
