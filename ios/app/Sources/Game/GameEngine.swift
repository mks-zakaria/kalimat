import Foundation
import Observation

/// One letter key in the bank. `id` keeps duplicates (two "ا") distinct.
struct BankKey: Identifiable, Hashable {
    let id: Int
    let letter: String
    var used = false
    var removed = false
}

/// Rules for one level: which cells are filled, which words are solved,
/// and the typing state of the word currently open. No UI in here.
@Observable
final class GameEngine {
    let level: Level
    private(set) var filled: [CellPos: String] = [:]     // letters the player has earned on the board
    private(set) var solved: Set<String> = []
    private(set) var revealed: Set<CellPos> = []          // filled by a hint (shown in hint colour)

    // Open word
    private(set) var current: Entry?
    private(set) var typed: [String?] = []                // one per letter of `current`
    private(set) var typedFrom: [Int?] = []               // bank key id that produced each typed letter
    private(set) var bank: [BankKey] = []
    private(set) var lastWrong = false

    static let bankSize = 12

    init(level: Level) { self.level = level }

    // MARK: board

    var cellMap: [CellPos: Entry] {
        var m: [CellPos: Entry] = [:]
        for e in level.entries { for c in e.cells where m[c] == nil { m[c] = e } }
        return m
    }

    var allCells: Set<CellPos> { Set(level.entries.flatMap(\.cells)) }

    var isComplete: Bool { solved.count == level.entries.count }

    /// Words through a cell; tapping a crossing cell twice toggles between them.
    func entries(at cell: CellPos) -> [Entry] {
        level.entries.filter { $0.cells.contains(cell) }
    }

    func entryToOpen(at cell: CellPos, previous: Entry?) -> Entry? {
        let options = entries(at: cell).filter { !solved.contains($0.id) }
        guard !options.isEmpty else { return nil }
        if let previous, let i = options.firstIndex(of: previous), options.count > 1 {
            return options[(i + 1) % options.count]
        }
        return options.first
    }

    // MARK: open word

    func open(_ entry: Entry) {
        current = entry
        lastWrong = false
        // letters already known from crossing words are pre-filled and locked
        typed = entry.cells.map { filled[$0] }
        typedFrom = Array(repeating: nil, count: entry.answer.count)
        bank = makeBank(for: entry)
    }

    func isLocked(_ index: Int) -> Bool {
        guard let e = current else { return false }
        return filled[e.cells[index]] != nil
    }

    func tapKey(_ key: BankKey) {
        guard current != nil, !key.used, !key.removed,
              let slot = typed.indices.first(where: { typed[$0] == nil }) else { return }
        lastWrong = false
        typed[slot] = key.letter
        typedFrom[slot] = key.id
        bank[bank.firstIndex(of: key)!].used = true
        if !typed.contains(where: { $0 == nil }) { check() }
    }

    func tapSlot(_ index: Int) {
        guard typed.indices.contains(index), !isLocked(index), let keyId = typedFrom[index] else { return }
        typed[index] = nil
        typedFrom[index] = nil
        if let k = bank.firstIndex(where: { $0.id == keyId }) { bank[k].used = false }
    }

    var currentSolved: Bool { current.map { solved.contains($0.id) } ?? false }

    private func check() {
        guard let e = current else { return }
        if typed.compactMap({ $0 }).joined() == e.answer {
            solve(e)
        } else {
            lastWrong = true
            for i in typed.indices where !isLocked(i) { tapSlot(i) }
        }
    }

    private func solve(_ e: Entry) {
        solved.insert(e.id)
        for (i, c) in e.cells.enumerated() { filled[c] = e.letters[i] }
        // a crossing word whose every cell is now filled is solved too
        for other in level.entries where !solved.contains(other.id) {
            if other.cells.allSatisfy({ filled[$0] != nil }) { solved.insert(other.id) }
        }
    }

    // MARK: bank

    private func makeBank(for e: Entry) -> [BankKey] {
        var rng = SeededRNG(seed: level.id + e.id)
        // only letters still to be typed go in the bank (locked ones are already placed)
        var letters = e.letters.enumerated().filter { filled[e.cells[$0.offset]] == nil }.map(\.element)
        while letters.count < max(Self.bankSize, letters.count) {
            letters.append(ArabicText.decoys.randomElement(using: &rng)!)
        }
        letters.shuffle(using: &rng)
        return letters.enumerated().map { BankKey(id: $0.offset, letter: $0.element) }
    }
}
