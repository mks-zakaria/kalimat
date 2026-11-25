import XCTest

/// Taps every hittable button on every screen and checks that something on
/// screen changed. A control that changes nothing is a dead control (bug B01:
/// the coin counter looked like a switch and did nothing).
///
/// How "changed" is measured: the accessibility tree (labels, values, frames,
/// enabled state) before and after the tap, with memory addresses stripped.
/// Animations that aren't in the tree (drifting sun, pulsing glow) don't count.
final class DeadControlAudit: XCTestCase {

    struct Screen { let name: String; let args: [String] }

    let screens = [
        Screen(name: "home", args: []),
        Screen(name: "packs", args: ["-screen", "packs"]),
        Screen(name: "levels", args: ["-screen", "levels"]),
        Screen(name: "board", args: ["-screen", "level", "-level", "p01-001"]),
        Screen(name: "wspacks", args: ["-screen", "wspacks"]),
        Screen(name: "wordsearch", args: ["-screen", "level", "-level", "p01-w001"]),
    ]

    func launch(_ s: Screen) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-reset", "-uitest"] + s.args
        app.launch()
        _ = app.buttons.firstMatch.waitForExistence(timeout: 5)
        sleep(1)
        return app
    }

    func tree(_ app: XCUIApplication) -> String {
        app.debugDescription
            .replacingOccurrences(of: #"0x[0-9a-f]+"#, with: "", options: .regularExpression)
            .split(separator: "\n").filter { !$0.contains("Timestamp") }.joined(separator: "\n")
    }

    /// Stable handle for a button: identifier, else label + occurrence.
    func handles(_ app: XCUIApplication) -> [(key: String, find: (XCUIApplication) -> XCUIElement)] {
        var seen: [String: Int] = [:]
        var out: [(String, (XCUIApplication) -> XCUIElement)] = []
        for (i, b) in app.buttons.allElementsBoundByIndex.enumerated() where b.isHittable {
            if !b.identifier.isEmpty {
                let id = b.identifier
                out.append((id, { $0.buttons[id] }))
            } else {
                let label = b.label
                let n = seen[label, default: 0]; seen[label] = n + 1
                out.append(("\"\(label)\"#\(n)", { app in
                    app.buttons.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex[safe: n] ?? app.buttons.element(boundBy: i)
                }))
            }
        }
        return out
    }

    func testDeadControlAudit() {
        var dead: [String] = [], info: [String] = [], disabled: [String] = [], checked = 0
        for screen in screens {
            let first = launch(screen)
            let all = handles(first)
            for b in first.buttons.allElementsBoundByIndex where b.exists && !b.isEnabled {
                disabled.append("\(screen.name): \(b.identifier.isEmpty ? b.label : b.identifier)")
            }
            first.terminate()
            for h in all {
                let app = launch(screen)
                let el = h.find(app)
                guard el.exists, el.isHittable, el.isEnabled else { app.terminate(); continue }
                let before = tree(app)
                el.tap()
                sleep(1)
                let after = tree(app)
                checked += 1
                if before == after {
                    // Grid cells of the word already open, or of a solved word, legitimately do nothing new.
                    // ...and so does a control that is already selected (the current mode tab,
                    // the selected clue): choosing it again has nothing to change.
                    if h.key.hasPrefix("cell.") || el.isSelected { info.append("\(screen.name): \(h.key)") }
                    else { dead.append("\(screen.name): \(h.key)") }
                }
                app.terminate()
            }
        }
        let report = """
        Dead-control audit — \(checked) controls tapped on \(screens.count) screens
        DEAD (\(dead.count)): \(dead.joined(separator: ", "))
        Expected no-ops (open word cells, already-selected controls) (\(info.count)): \(info.joined(separator: ", "))
        Disabled at start (\(disabled.count)): \(disabled.joined(separator: ", "))
        """
        print("AUDIT-REPORT\n" + report + "\nAUDIT-END")
        let att = XCTAttachment(string: report); att.lifetime = .keepAlways; add(att)
        XCTAssertTrue(dead.isEmpty, "dead controls: \(dead.joined(separator: ", "))")
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
