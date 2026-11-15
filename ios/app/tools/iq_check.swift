// macOS logic check for the IQ score and the save-file changes it needed.
// swiftc -parse-as-library tools/iq_check.swift Sources/Models/Content.swift Sources/Game/*.swift Sources/Services/ProgressStore.swift -o /tmp/iqcheck && /tmp/iqcheck Resources/Packs
import Foundation

@main
struct IQCheck {
    static func main() throws {
        var fails = 0
        func expect(_ c: Bool, _ m: String) { if !c { fails += 1; print("FAIL", m) } }

        // level score
        expect(IQ.levelScore(expected: 90, actual: 90, hints: 0) == 100, "on pace = 100")
        expect(IQ.levelScore(expected: 90, actual: 45, hints: 0) == 120, "twice as fast = 120")
        expect(IQ.levelScore(expected: 90, actual: 180, hints: 0) == 80, "twice as slow = 80")
        expect(IQ.levelScore(expected: 90, actual: 90, hints: 2) == 90, "hints cost 5 each")
        expect(IQ.levelScore(expected: 90, actual: 0.5, hints: 0) == 160, "capped at 160")
        expect(IQ.levelScore(expected: 90, actual: 99999, hints: 0) == 70, "floored at 70")

        // overall blend
        expect(IQ.updated(global: nil, count: 0, with: 112) == 112, "first level sets IQ")
        expect(IQ.updated(global: 100, count: 1, with: 120) == 110, "second level: half way")
        expect(abs(IQ.updated(global: 100, count: 50, with: 120) - 103) < 0.001, "later levels: 15 %")

        // expected times are sane for every bundled level
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        let packs = try files.map { try JSONDecoder().decode(Pack.self, from: Data(contentsOf: $0)) }
        let cw = packs.flatMap(\.levels).map { IQ.expectedSeconds($0, mode: .crossword) }
        let ws = WordSearchContent.packs(from: packs).flatMap(\.levels).map {
            IQ.expectedSeconds($0, mode: .wordSearch, gridSize: WordSearchGenerator.make(level: $0).size)
        }
        print(String(format: "expected crossword %.0f–%.0f s (avg %.0f), word search %.0f–%.0f s (avg %.0f)",
                     cw.min()!, cw.max()!, cw.reduce(0, +) / Double(cw.count), ws.min()!, ws.max()!, ws.reduce(0, +) / Double(ws.count)))
        expect(cw.allSatisfy { (20...400).contains($0) } && ws.allSatisfy { (20...400).contains($0) }, "expected times in range")

        // saves from before this version still load (no elapsed / iq keys)
        let old = #"{"version":1,"coins":75,"levels":{"p01-001":{"filled":{},"solved":["a"],"revealed":[],"removedDecoys":{},"hintsUsed":1,"stars":2,"completedAt":"2026-11-14T10:00:00Z"}},"settings":{"sound":true}}"#
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("iqcheck-\(UUID()).json")
        try old.data(using: .utf8)!.write(to: url)
        let store = ProgressStore(url: url)
        expect(store.coins == 75 && store.isComplete("p01-001"), "old save keeps progress")
        expect(store.iq == nil, "old save has no IQ yet")

        // time + IQ through the store
        store.addTime("p01-002", 30); store.addTime("p01-002", 15)
        expect(store.progress(for: "p01-002")?.elapsed == 45, "time accumulates")
        var p = store.progress(for: "p01-002")!; p.completedAt = Date(); p.stars = 3
        store.update("p01-002", p)                                  // an engine snapshot has elapsed 0...
        expect(store.progress(for: "p01-002")?.elapsed == 45, "...and update keeps the clock's time")
        let r1 = store.recordIQ("p01-002", expected: 90, hints: 0)
        expect(r1.counted && r1.level == 120 && r1.before == nil && r1.after == 120, "first IQ = 120")
        store.addTime("p01-002", 500)
        expect(store.progress(for: "p01-002")?.elapsed == 45, "no time added after scoring")
        let replay = store.recordIQ("p01-002", expected: 90, hints: 0)
        expect(!replay.counted && store.iq == 120, "replay does not count")
        store.addTime("p01-003", 180)
        let r2 = store.recordIQ("p01-003", expected: 90, hints: 0)
        expect(r2.level == 80 && r2.before == 120 && r2.after == 100, "second level blends: 120 → 100")
        store.addTime("p01-004", 7 * 3600)
        expect(store.progress(for: "p01-004") == nil, "clock jumps ignored")

        let reloaded = ProgressStore(url: url)
        expect(reloaded.iq == 100 && reloaded.file.iqLevels == 2, "IQ persists")
        try? FileManager.default.removeItem(at: url)

        print(fails == 0 ? "ALL IQ CHECKS PASSED" : "\(fails) FAILURES")
        exit(fails == 0 ? 0 : 1)
    }
}
