// macOS logic check for the word-search mode against every bundled pack.
// swiftc -parse-as-library tools/wordsearch_check.swift Sources/Models/Content.swift Sources/Game/*.swift -o /tmp/wscheck && /tmp/wscheck Resources/Packs
import Foundation

@main
struct WSCheck {
    static func main() throws {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
        let packs = try files.map { try JSONDecoder().decode(Pack.self, from: Data(contentsOf: $0)) }
        var fails = 0
        func expect(_ c: Bool, _ m: String) { if !c { fails += 1; print("FAIL", m) } }

        let ws = WordSearchContent.packs(from: packs)
        let ws2 = WordSearchContent.packs(from: packs)
        expect(ws.map { $0.levels.map(\.id) } == ws2.map { $0.levels.map(\.id) }, "grouping deterministic")
        var sizes: [Int: Int] = [:], dirs: [String: Int] = [:], levels = 0
        for (p, w) in zip(packs, ws) {
            let a = Set(p.levels.flatMap(\.entries).map(\.id)), b = w.levels.flatMap(\.entries).map(\.id)
            expect(a == Set(b) && b.count == a.count, "\(w.id) uses every word of \(p.id) exactly once")
            for level in w.levels {
                levels += 1
                let crosswordCopy = p.levels.contains { Set($0.entries.map(\.id)) == Set(level.entries.map(\.id)) }
                expect(!crosswordCopy, "\(level.id) is not a copy of a crossword level")
                let pz = WordSearchGenerator.make(level: level)
                let pz2 = WordSearchGenerator.make(level: level)
                expect(pz.grid == pz2.grid, "\(level.id) grid deterministic")
                expect(pz.size <= 10, "\(level.id) size \(pz.size) fits a phone")
                sizes[pz.size, default: 0] += 1
                for e in level.entries {
                    guard let pl = pz.placements[e.id] else { expect(false, "\(level.id) \(e.answer) placed"); continue }
                    dirs["\(pl.dr),\(pl.dc)", default: 0] += 1
                    expect(pl.cells.allSatisfy { (0..<pz.size).contains($0.row) && (0..<pz.size).contains($0.col) }, "\(level.id) in bounds")
                    expect(pl.cells.map(pz.letter) == WordSearchGenerator.letters(e), "\(level.id) \(e.answer) spelled in grid")
                }
                // play it: wrong line, reversed line, every word, stars
                let g = WordSearchEngine(level: level)
                var saved: LevelProgress?
                g.onProgress = { saved = $0 }
                expect(g.select([CellPos(row: 0, col: 0)]) == .tooShort, "single cell ignored")
                for (i, e) in level.entries.enumerated() {
                    var cells = pz.placements[e.id]!.cells
                    if i % 2 == 1 { cells.reverse() }                 // drawn backwards still counts
                    if g.isFound(e) { continue }      // already found as another word read backwards (سوق / قوس)
                    if case .found(let got) = g.select(cells) { expect(got == e, "\(level.id) \(e.answer) matched itself") }
                    else { expect(false, "\(level.id) \(e.answer) accepted") }
                    if case .found(let again) = g.select(cells) {
                        expect(again != e, "\(level.id) same word twice rejected")   // a backwards twin may match
                    }
                }
                expect(g.isComplete && g.stars == 3, "\(level.id) complete with 3 stars")
                expect(saved?.completedAt != nil && saved?.solved.count == level.entries.count, "\(level.id) saved")
                let back = WordSearchEngine(level: level, saved: saved)
                expect(back.isComplete, "\(level.id) restores")
            }
        }
        // hints and stars
        let lv = ws[0].levels[0], h = WordSearchEngine(level: lv), e = lv.entries[0]
        h.showWord(e); h.showWord(e); h.showStart(e)
        expect(h.hintsUsed == 2, "a hint is charged once per word")
        let restored = WordSearchEngine(level: lv, saved: h.snapshot())
        expect(restored.shownWords.contains(e.id) && restored.shownStarts.contains(e.id), "hint marks restore")
        expect(WordSearchEngine.line(from: CellPos(row: 0, col: 0), to: CellPos(row: 2, col: 1)) == nil, "bent line rejected")
        expect(WordSearchEngine.line(from: CellPos(row: 3, col: 3), to: CellPos(row: 0, col: 0))?.count == 4, "diagonal line")

        print("word-search levels: \(levels) in \(ws.count) packs (\(ws.map { String($0.levels.count) }.joined(separator: ",")))")
        print("grid sizes:", sizes.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.key): \($0.value)" }.joined(separator: ", "))
        print("directions (dr,dc):", dirs.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))
        print(fails == 0 ? "ALL WORD-SEARCH CHECKS PASSED" : "\(fails) FAILURES")
        exit(fails == 0 ? 0 : 1)
    }
}
