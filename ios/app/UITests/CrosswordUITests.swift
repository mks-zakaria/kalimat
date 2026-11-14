import XCTest

/// End-to-end tests for the main flows (replica/test-plan.md).
/// Each test starts from a clean save (`-reset`, debug builds only).
final class CrosswordUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    // MARK: helpers

    func launch(_ args: [String] = [], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-reset"] : []) + args
        app.launch()
        return app
    }

    /// Reads a level from the same JSON the app ships (bundled into the test target too).
    func level(_ id: String) -> [String: Any] {
        let bundle = Bundle(for: Self.self)
        for url in bundle.urls(forResourcesWithExtension: "json", subdirectory: "Packs") ?? [] {
            let pack = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
            for l in pack["levels"] as! [[String: Any]] where l["id"] as! String == id { return l }
        }
        XCTFail("level \(id) not found in test bundle"); return [:]
    }

    func entries(_ level: [String: Any]) -> [[String: Any]] { level["entries"] as! [[String: Any]] }

    /// The entry whose clue is on screen.
    func currentEntry(_ app: XCUIApplication, _ level: [String: Any]) -> [String: Any]? {
        entries(level).first { app.staticTexts[$0["clue_ar"] as! String].exists }
    }

    func coins(_ app: XCUIApplication) -> String { app.buttons["coins.button"].label }

    /// Type the open word using the letter keys (only slots that are still empty).
    func typeAnswer(_ app: XCUIApplication, _ entry: [String: Any]) {
        let letters = (entry["answer"] as! String).map(String.init)
        for (i, letter) in letters.enumerated() {
            let slot = app.descendants(matching: .any)["slot.\(i)"]
            guard slot.waitForExistence(timeout: 2), slot.label == "فارغ" else { continue }
            let key = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'key.' AND label == %@ AND isEnabled == true", letter)).firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 2), "key \(letter) missing for \(entry["answer"]!)")
            key.tap()
        }
    }

    // MARK: F01 solve

    func testSolveFirstLevelEndToEnd() {
        let app = launch(["-screen", "level", "-level", "p01-001"])
        let lvl = level("p01-001")
        XCTAssertTrue(app.buttons["coins.button"].waitForExistence(timeout: 5))
        let before = coins(app)
        for _ in 0..<entries(lvl).count {
            if app.buttons["complete.next"].exists { break }
            guard let e = currentEntry(app, lvl) else { break }
            typeAnswer(app, e)
            sleep(1)   // auto-advance to the next word
        }
        XCTAssertTrue(app.buttons["complete.next"].waitForExistence(timeout: 5), "celebration did not appear")
        XCTAssertNotEqual(coins(app), before, "no coin reward for a new level")
        XCTAssertTrue(coins(app).contains("١١٠"), "3 stars without hints should give +10 (got \(coins(app)))")
    }

    func testWrongAnswerClearsSlots() throws {
        let app = launch(["-screen", "level", "-level", "p01-001"])
        let lvl = level("p01-001")
        guard let e = currentEntry(app, lvl) else { return XCTFail("no clue on screen") }
        // the right letters in the wrong order: always available in the bank
        let answer = (e["answer"] as! String).map(String.init)
        let n = answer.count
        let wrongOrder = Array(answer.reversed())
        guard wrongOrder != answer else { throw XCTSkip("palindrome answer") }
        let before = coins(app)
        for letter in wrongOrder {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'key.' AND label == %@ AND isEnabled == true", letter)).firstMatch.tap()
        }
        sleep(1)
        for i in 0..<n { XCTAssertEqual(app.descendants(matching: .any)["slot.\(i)"].label, "فارغ", "slot \(i) not cleared") }
        XCTAssertEqual(coins(app), before)
    }

    func testTapSlotReturnsLetter() {
        let app = launch(["-screen", "level", "-level", "p01-001"])
        let key = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'key.' AND isEnabled == true")).firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        let id = key.identifier
        key.tap()
        XCTAssertFalse(app.buttons[id].isEnabled, "used key should be disabled")
        app.descendants(matching: .any)["slot.0"].tap()
        XCTAssertTrue(app.buttons[id].isEnabled, "letter did not return to the keys")
    }

    func testProgressSurvivesRelaunch() {
        var app = launch(["-screen", "level", "-level", "p01-001"])
        let lvl = level("p01-001")
        guard let e = currentEntry(app, lvl) else { return XCTFail("no clue on screen") }
        typeAnswer(app, e)
        sleep(1)
        let row = e["row"] as! Int, col = e["col"] as! Int
        let cell = app.descendants(matching: .any)["cell.\(row).\(col)"]
        XCTAssertNotEqual(cell.label, "خانة فارغة")
        app.terminate()
        app = launch(["-screen", "level", "-level", "p01-001"], reset: false)
        let again = app.descendants(matching: .any)["cell.\(row).\(col)"]
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        XCTAssertNotEqual(again.label, "خانة فارغة", "solved word lost after relaunch")
    }

    // MARK: F02 hints

    func testRevealHintCostsCoins() {
        let app = launch(["-screen", "level", "-level", "p01-001"])
        XCTAssertTrue(app.buttons["hint.reveal"].waitForExistence(timeout: 5))
        app.buttons["hint.reveal"].tap()
        sleep(1)
        XCTAssertTrue(coins(app).contains("٨٠"), "reveal should cost 20 (got \(coins(app)))")
        XCTAssertNotEqual(app.descendants(matching: .any)["slot.0"].label, "فارغ", "first letter not revealed")
    }

    func testRemoveHintCostsCoins() {
        let app = launch(["-screen", "level", "-level", "p01-001"])
        let keys = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'key.'"))
        XCTAssertTrue(app.buttons["hint.remove"].waitForExistence(timeout: 5))
        let before = keys.allElementsBoundByIndex.filter(\.isHittable).count
        app.buttons["hint.remove"].tap()
        sleep(1)
        XCTAssertTrue(coins(app).contains("٩٠"), "remove should cost 10 (got \(coins(app)))")
        XCTAssertEqual(keys.allElementsBoundByIndex.filter(\.isHittable).count, before - 1, "no key removed")
    }

    // MARK: F03 / F05

    func testCoinButtonOpensCoinsScreen() {
        let app = launch()
        let coin = app.buttons["coins.button"]
        XCTAssertTrue(coin.waitForExistence(timeout: 5))
        coin.tap()
        XCTAssertTrue(app.staticTexts["coins.balance"].waitForExistence(timeout: 3), "coin counter does nothing")
        app.buttons["coins.close"].tap()
    }

    func testSoundToggleOnEveryScreen() {
        for args in [[], ["-screen", "packs"], ["-screen", "levels"], ["-screen", "level", "-level", "p01-001"]] {
            let app = launch(args)
            let sound = app.buttons["sound.button"]
            XCTAssertTrue(sound.waitForExistence(timeout: 5), "no sound button on \(args)")
            let before = sound.label
            sound.tap()
            XCTAssertNotEqual(sound.label, before, "sound button did not toggle on \(args)")
            app.terminate()
            // the setting is remembered
            let again = launch(args, reset: false)
            XCTAssertNotEqual(again.buttons["sound.button"].label, before, "sound setting not saved on \(args)")
            again.terminate()
        }
    }

    func testLockedLevelShowsMessage() {
        let app = launch(["-screen", "levels"])
        let locked = app.buttons["level.p01-002"]
        XCTAssertTrue(locked.waitForExistence(timeout: 5))
        locked.tap()
        XCTAssertTrue(app.descendants(matching: .any)["toast"].waitForExistence(timeout: 2), "locked level gives no feedback")
    }
}
