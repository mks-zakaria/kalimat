import Foundation
import Observation

/// One letter key in the bank. `id` keeps duplicates (two "ا") distinct.
struct BankKey: Identifiable, Hashable {
    let id: Int
    let letter: String
    let isDecoy: Bool
    var used = false
    var removed = false
}

/// What a level saves: only letters the player has earned (solved or revealed),
/// so a half-typed word is never "remembered" wrongly.
struct LevelProgress: Codable, Equatable {
    var filled: [String: String] = [:]      // "row,col" -> letter
    var solved: [String] = []
    var revealed: [String] = []             // "row,col" filled by a hint
    var removedDecoys: [String: Int] = [:]  // entry id -> decoys removed by hint
    var hintsUsed = 0
    var stars = 0
    var completedAt: Date?
    var elapsed: Double = 0                 // active solving seconds (SolveClock), kept by ProgressStore
    var iq: Int?                            // this level's IQ score at its first completion

    init(filled: [String: String] = [:], solved: [String] = [], revealed: [String] = [],
         removedDecoys: [String: Int] = [:], hintsUsed: Int = 0, stars: Int = 0, completedAt: Date? = nil) {
        self.filled = filled; self.solved = solved; self.revealed = revealed
        self.removedDecoys = removedDecoys; self.hintsUsed = hintsUsed; self.stars = stars
        self.completedAt = completedAt
    }

    /// Missing keys fall back to defaults, so saves from older versions still load.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        filled = try c.decodeIfPresent([String: String].self, forKey: .filled) ?? [:]
        solved = try c.decodeIfPresent([String].self, forKey: .solved) ?? []
        revealed = try c.decodeIfPresent([String].self, forKey: .revealed) ?? []
        removedDecoys = try c.decodeIfPresent([String: Int].self, forKey: .removedDecoys) ?? [:]
        hintsUsed = try c.decodeIfPresent(Int.self, forKey: .hintsUsed) ?? 0
        stars = try c.decodeIfPresent(Int.self, forKey: .stars) ?? 0
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        elapsed = try c.decodeIfPresent(Double.self, forKey: .elapsed) ?? 0
        iq = try c.decodeIfPresent(Int.self, forKey: .iq)
    }
}

/// Rules for one level. No UI and no coins in here: callers check the wallet
/// first, then call `revealLetter()` / `removeDecoy()`.
@Observable
final class GameEngine {
    let level: Level
    private(set) var filled: [CellPos: String] = [:]
    private(set) var solved: Set<String> = []
    private(set) var revealed: Set<CellPos> = []
    private(set) var hintsUsed = 0
    private var removedDecoys: [String: Int] = [:]

    // Open word
    private(set) var current: Entry?
    private(set) var typed: [String?] = []
    private(set) var typedFrom: [Int?] = []
    private(set) var bank: [BankKey] = []
    private(set) var lastWrong = false

    /// Called after every change worth saving.
    var onProgress: ((LevelProgress) -> Void)?

    static let bankSize = 12

    init(level: Level, saved: LevelProgress? = nil) {
        self.level = level
        if let saved {
            for (k, v) in saved.filled { if let c = CellPos(key: k) { filled[c] = v } }
            solved = Set(saved.solved)
            revealed = Set(saved.revealed.compactMap(CellPos.init(key:)))
            hintsUsed = saved.hintsUsed
            removedDecoys = saved.removedDecoys
        }
    }

    // MARK: board

    var allCells: Set<CellPos> { Set(level.entries.flatMap(\.cells)) }
    var isComplete: Bool { solved.count == level.entries.count }

    /// 3 stars with no hints, 2 with up to two, else 1.
    var stars: Int { !isComplete ? 0 : hintsUsed == 0 ? 3 : hintsUsed <= 2 ? 2 : 1 }

    func entries(at cell: CellPos) -> [Entry] {
        level.entries.filter { $0.cells.contains(cell) }
    }

    /// Tapping a crossing cell again switches to the other word.
    func entryToOpen(at cell: CellPos, previous: Entry?) -> Entry? {
        let options = entries(at: cell).filter { !solved.contains($0.id) }
        guard !options.isEmpty else { return nil }
        if let previous, let i = options.firstIndex(of: previous), options.count > 1 {
            return options[(i + 1) % options.count]
        }
        return options.first
    }

    /// The next unsolved word after `entry` (wrapping), for auto-advance.
    func nextUnsolved(after entry: Entry?) -> Entry? {
        let list = level.entries
        let start = entry.flatMap { list.firstIndex(of: $0) } ?? -1
        for k in 1...max(list.count, 1) {
            let e = list[(start + k + list.count) % list.count]
            if !solved.contains(e.id) { return e }
        }
        return nil
    }

    // MARK: open word

    func open(_ entry: Entry) {
        current = entry
        lastWrong = false
        typed = entry.cells.map { filled[$0] }
        typedFrom = Array(repeating: nil, count: entry.answer.count)
        bank = makeBank(for: entry)
    }

    func isLocked(_ index: Int) -> Bool {
        guard let e = current, e.cells.indices.contains(index) else { return false }
        return filled[e.cells[index]] != nil
    }

    func isRevealed(_ index: Int) -> Bool {
        guard let e = current, e.cells.indices.contains(index) else { return false }
        return revealed.contains(e.cells[index])
    }

    var currentSolved: Bool { current.map { solved.contains($0.id) } ?? false }

    func tapKey(_ key: BankKey) {
        guard current != nil, !currentSolved,
              let k = bank.firstIndex(where: { $0.id == key.id }), !bank[k].used, !bank[k].removed,
              let slot = typed.indices.first(where: { typed[$0] == nil }) else { return }
        lastWrong = false
        typed[slot] = bank[k].letter
        typedFrom[slot] = bank[k].id
        bank[k].used = true
        if !typed.contains(where: { $0 == nil }) { check() }
    }

    func tapSlot(_ index: Int) {
        guard typed.indices.contains(index), !isLocked(index), let keyId = typedFrom[index] else { return }
        typed[index] = nil
        typedFrom[index] = nil
        if let k = bank.firstIndex(where: { $0.id == keyId }) { bank[k].used = false }
    }

    // MARK: hints

    var canReveal: Bool { current != nil && !currentSolved }
    var canRemoveDecoy: Bool { !currentSolved && bank.contains { $0.isDecoy && !$0.removed && !$0.used } }

    /// Puts the right letter in the first open slot (right-most), locked, in hint colour.
    func revealLetter() {
        guard let e = current, canReveal,
              let i = e.cells.indices.first(where: { filled[e.cells[$0]] == nil }) else { return }
        clearTyped()
        filled[e.cells[i]] = e.letters[i]
        revealed.insert(e.cells[i])
        hintsUsed += 1
        let removed = removedDecoys[e.id] ?? 0
        open(e)                                           // rebuild bank without that letter
        for _ in 0..<removed { removeOneDecoy() }
        if e.cells.allSatisfy({ filled[$0] != nil }) { solve(e) } else { save() }
    }

    /// Hides one letter that is not in the answer.
    func removeDecoy() {
        guard let e = current, canRemoveDecoy else { return }
        removeOneDecoy()
        removedDecoys[e.id, default: 0] += 1
        hintsUsed += 1
        save()
    }

    private func removeOneDecoy() {
        if let k = bank.firstIndex(where: { $0.isDecoy && !$0.removed && !$0.used }) { bank[k].removed = true }
    }

    private func clearTyped() {
        for i in typed.indices where !isLocked(i) { tapSlot(i) }
    }

    // MARK: checking

    private func check() {
        guard let e = current else { return }
        if typed.compactMap({ $0 }).joined() == e.answer {
            solve(e)
        } else {
            lastWrong = true
            clearTyped()
        }
    }

    private func solve(_ e: Entry) {
        solved.insert(e.id)
        for (i, c) in e.cells.enumerated() { filled[c] = e.letters[i] }
        typed = e.letters
        for other in level.entries where !solved.contains(other.id) {
            if other.cells.allSatisfy({ filled[$0] != nil }) { solved.insert(other.id) }
        }
        save()
    }

    // MARK: saving

    var snapshot: LevelProgress {
        LevelProgress(filled: Dictionary(uniqueKeysWithValues: filled.map { ($0.key.key, $0.value) }),
                      solved: solved.sorted(),
                      revealed: revealed.map(\.key).sorted(),
                      removedDecoys: removedDecoys,
                      hintsUsed: hintsUsed,
                      stars: stars,
                      completedAt: isComplete ? Date() : nil)
    }

    private func save() { onProgress?(snapshot) }

    // MARK: bank

    private func makeBank(for e: Entry) -> [BankKey] {
        var rng = SeededRNG(seed: level.id + e.id)
        let needed = e.letters.enumerated().filter { filled[e.cells[$0.offset]] == nil }.map(\.element)
        var keys = needed.map { ($0, false) }
        // decoys are drawn from a fixed-seed stream so they don't change after a reveal
        var decoyRNG = SeededRNG(seed: "d" + level.id + e.id)
        while keys.count < Self.bankSize {
            keys.append((ArabicText.decoys.randomElement(using: &decoyRNG)!, true))
        }
        keys.shuffle(using: &rng)
        return keys.enumerated().map { BankKey(id: $0.offset, letter: $0.element.0, isDecoy: $0.element.1) }
    }
}

extension CellPos {
    var key: String { "\(row),\(col)" }
    init?(key: String) {
        let p = key.split(separator: ",").compactMap { Int($0) }
        guard p.count == 2 else { return nil }
        self.init(row: p[0], col: p[1])
    }
}
