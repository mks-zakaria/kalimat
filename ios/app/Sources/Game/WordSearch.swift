import Foundation
import Observation

/// Second way to play ("كلمات مخفية"): every answer is hidden in a square of letters and
/// the player draws a straight line over it — across, down or diagonally. The clue is
/// shown, the word is not, so it stays a clue game rather than a plain word list.
enum GameMode: String, Hashable {
    case crossword, wordSearch

    var title: String { self == .crossword ? "كلمات متقاطعة" : "كلمات مخفية" }
}

extension Pack {
    var isWordSearch: Bool { id.hasPrefix(WordSearchContent.packPrefix) }
}

// MARK: - Content: regroup the clue bank into word-search levels

/// Word-search packs are derived from the crossword packs at launch: the same clue bank,
/// regrouped (shuffled, easy words first, about 7 per level), so a word-search level is
/// never a copy of a crossword level. Deterministic: same groups on every launch and device.
enum WordSearchContent {
    static let packPrefix = "ws-"
    static let wordsPerLevel = 7

    static func packs(from packs: [Pack]) -> [Pack] {
        packs.map { pack in
            Pack(id: packPrefix + pack.id, titleAr: pack.titleAr, order: pack.order,
                 region: pack.region, levels: group(pack))
        }
    }

    private static func group(_ pack: Pack) -> [Level] {
        var rng = SeededRNG(seed: "ws-pack:" + pack.id)
        let words = pack.levels.flatMap(\.entries)
            .map { ($0, UInt64.random(in: 0...UInt64.max, using: &rng)) }
            .sorted { ($0.0.difficulty, $0.1) < ($1.0.difficulty, $1.1) }
            .map(\.0)
        let count = max(1, Int((Double(words.count) / Double(wordsPerLevel)).rounded()))
        var groups: [[Entry]] = (0..<count).map { i in
            Array(words[(words.count * i / count)..<(words.count * (i + 1) / count)])
        }.filter { !$0.isEmpty }

        // Never hand the player a crossword level again as a word search. Sorting by
        // difficulty can rebuild one (a crossword level made only of the hardest words),
        // so trade one word with the neighbouring group.
        let crossword = Set(pack.levels.map { Set($0.entries.map(\.id)) })
        for i in groups.indices where crossword.contains(Set(groups[i].map(\.id))) && groups.count > 1 {
            let j = i > 0 ? i - 1 : i + 1
            let a = groups[i].removeFirst(), b = groups[j].removeLast()
            groups[i].insert(b, at: 0)
            groups[j].append(a)
        }
        return groups.enumerated().map { i, g in
            Level(id: String(format: "%@-w%03d", pack.id, i + 1), number: i + 1, width: 0, height: 0, entries: g)
        }
    }
}

// MARK: - Puzzle generation

struct WSPlacement: Hashable {
    let entryId: String
    let start: CellPos
    let dr: Int
    let dc: Int
    let length: Int

    var cells: [CellPos] { (0..<length).map { CellPos(row: start.row + dr * $0, col: start.col + dc * $0) } }
}

struct WordSearchPuzzle {
    let size: Int
    let grid: [[String]]               // grid[row][col]; col 0 is the RIGHTMOST column
    let placements: [String: WSPlacement]

    func letter(_ c: CellPos) -> String { grid[c.row][c.col] }
}

enum WordSearchGenerator {
    /// (dr, dc) with col 0 on the right: (0,1) reads right-to-left like Arabic,
    /// (1,0) top to bottom, (1,1) and (1,-1) the two downward diagonals.
    static let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]

    /// Filler letters, weighted toward common ones so the grid looks like Arabic text.
    static let filler: [String] = "اااللليييوووممنننررتتببههعكدسقفجحخشصطزذثغضظأإة".map(String.init)

    static func letters(_ e: Entry) -> [String] { ArabicText.normalise(e.answer).map(String.init) }

    static func make(level: Level) -> WordSearchPuzzle {
        let words = level.entries.map { ($0.id, letters($0)) }.sorted { $0.1.count > $1.1.count }
        let total = words.reduce(0) { $0 + $1.1.count }
        let longest = words.map(\.1.count).max() ?? 4
        var size = min(10, max(6, longest, Int(ceil(sqrt(Double(total) * 1.9)))))
        var rng = SeededRNG(seed: "ws:" + level.id)

        while true {
            for _ in 0..<40 {
                if let p = attempt(words, size: size, rng: &rng) { return p }
            }
            size += 1            // could not fit: give the words more room
        }
    }

    private static func attempt(_ words: [(String, [String])], size: Int,
                                rng: inout SeededRNG) -> WordSearchPuzzle? {
        var grid = Array(repeating: Array(repeating: "", count: size), count: size)
        var placements: [String: WSPlacement] = [:]
        var dirUse = [Int](repeating: 0, count: directions.count)

        for (id, w) in words {
            var options: [(WSPlacement, Int)] = []          // placement, score
            for (di, d) in directions.enumerated() {
                for r in 0..<size {
                    for c in 0..<size {
                        let endR = r + d.0 * (w.count - 1), endC = c + d.1 * (w.count - 1)
                        guard (0..<size).contains(endR), (0..<size).contains(endC) else { continue }
                        var overlaps = 0, ok = true
                        for i in 0..<w.count {
                            let cell = grid[r + d.0 * i][c + d.1 * i]
                            if cell.isEmpty { continue }
                            if cell == w[i] { overlaps += 1 } else { ok = false; break }
                        }
                        guard ok, overlaps < w.count else { continue }
                        // favour unused directions (variety) and a little sharing of letters
                        let score = overlaps * 2 - dirUse[di] * 3 + Int.random(in: 0...4, using: &rng)
                        options.append((WSPlacement(entryId: id, start: CellPos(row: r, col: c),
                                                    dr: d.0, dc: d.1, length: w.count), score))
                    }
                }
            }
            guard let best = options.max(by: { $0.1 < $1.1 })?.0 else { return nil }
            for (i, cell) in best.cells.enumerated() { grid[cell.row][cell.col] = w[i] }
            placements[id] = best
            dirUse[directions.firstIndex { $0 == (best.dr, best.dc) }!] += 1
        }
        for r in 0..<size {
            for c in 0..<size where grid[r][c].isEmpty {
                grid[r][c] = filler.randomElement(using: &rng)!
            }
        }
        return WordSearchPuzzle(size: size, grid: grid, placements: placements)
    }
}

// MARK: - Rules

/// One word-search level. Saves through the same LevelProgress as the crossword:
/// `solved` = found entry ids; `revealed` = hint marks ("word:<id>", "start:<id>").
@Observable
final class WordSearchEngine {
    let level: Level
    let puzzle: WordSearchPuzzle
    /// Cells of each found word, as the player drew them.
    private(set) var found: [String: [CellPos]] = [:]
    private(set) var shownWords: Set<String> = []      // answer text revealed by a hint
    private(set) var shownStarts: Set<String> = []     // first letter marked by a hint
    private(set) var hintsUsed = 0
    private var completedAt: Date?

    var onProgress: ((LevelProgress) -> Void)?

    enum Result: Equatable { case found(Entry), wrong, tooShort }

    init(level: Level, saved: LevelProgress? = nil) {
        self.level = level
        self.puzzle = WordSearchGenerator.make(level: level)
        if let saved {
            for id in saved.solved { if let p = puzzle.placements[id] { found[id] = p.cells } }
            for mark in saved.revealed {
                if mark.hasPrefix("word:") { shownWords.insert(String(mark.dropFirst(5))) }
                if mark.hasPrefix("start:") { shownStarts.insert(String(mark.dropFirst(6))) }
            }
            hintsUsed = saved.hintsUsed
            completedAt = saved.completedAt
        }
    }

    var isComplete: Bool { found.count == level.entries.count }
    var stars: Int { !isComplete ? 0 : hintsUsed == 0 ? 3 : hintsUsed <= 2 ? 2 : 1 }
    func isFound(_ e: Entry) -> Bool { found[e.id] != nil }
    var firstUnfound: Entry? { level.entries.first { !isFound($0) } }

    /// Cells on the straight line from `a` to `b` (8 directions), or nil if not straight.
    static func line(from a: CellPos, to b: CellPos) -> [CellPos]? {
        let dr = b.row - a.row, dc = b.col - a.col
        guard dr == 0 || dc == 0 || abs(dr) == abs(dc) else { return nil }
        let n = max(abs(dr), abs(dc))
        let sr = dr.signum(), sc = dc.signum()
        return (0...n).map { CellPos(row: a.row + sr * $0, col: a.col + sc * $0) }
    }

    /// Checks a drawn line. Accepted in either drawing direction; the letters must spell an
    /// answer not found yet (an answer may also be found where it appears by chance).
    func select(_ cells: [CellPos]) -> Result {
        guard cells.count >= 2 else { return .tooShort }
        let drawn = cells.map(puzzle.letter)
        let reversed = Array(drawn.reversed())
        let open = level.entries.filter { !isFound($0) }
        // Some answers are other answers backwards (سوق / قوس): prefer the word hidden at
        // exactly these cells, then a forward reading, then a backward one.
        let here = Set(cells)
        guard let e = open.first(where: { puzzle.placements[$0.id].map { Set($0.cells) == here } ?? false })
                ?? open.first(where: { WordSearchGenerator.letters($0) == drawn })
                ?? open.first(where: { WordSearchGenerator.letters($0) == reversed })
        else { return .wrong }
        found[e.id] = cells
        if isComplete && completedAt == nil { completedAt = Date() }
        save()
        return .found(e)
    }

    // MARK: hints (the caller pays first)

    func canShowWord(_ e: Entry) -> Bool { !isFound(e) && !shownWords.contains(e.id) }
    func canShowStart(_ e: Entry) -> Bool { !isFound(e) && !shownStarts.contains(e.id) }
    func startCell(of e: Entry) -> CellPos? { puzzle.placements[e.id]?.start }

    func showWord(_ e: Entry) {
        guard canShowWord(e) else { return }
        shownWords.insert(e.id); hintsUsed += 1; save()
    }

    func showStart(_ e: Entry) {
        guard canShowStart(e) else { return }
        shownStarts.insert(e.id); hintsUsed += 1; save()
    }

    func snapshot() -> LevelProgress {
        LevelProgress(filled: [:], solved: level.entries.map(\.id).filter { found[$0] != nil },
                      revealed: shownWords.sorted().map { "word:" + $0 } + shownStarts.sorted().map { "start:" + $0 },
                      removedDecoys: [:], hintsUsed: hintsUsed, stars: stars, completedAt: completedAt)
    }

    private func save() { onProgress?(snapshot()) }
}
