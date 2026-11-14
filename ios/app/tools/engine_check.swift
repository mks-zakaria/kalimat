// macOS logic check for GameEngine against the generated packs (no simulator needed).
import Foundation

@main
struct Check {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let pack = try JSONDecoder().decode(Pack.self, from: data)
        var fails = 0
        func expect(_ c: Bool, _ m: String) { if !c { fails += 1; print("FAIL", m) } }

        expect(ArabicText.normalise("إِسْلَام") == "اسلام", "normalise tashkeel+hamza")
        expect(ArabicText.normalise("مُسْتَشْفَى") == "مستشفي", "normalise alef maqsura")
        var a = SeededRNG(seed: "x"), b = SeededRNG(seed: "x")
        expect(a.next() == b.next(), "seeded rng deterministic")

        for level in pack.levels {
            let g = GameEngine(level: level)
            // wrong answer first on the first word
            let first = level.entries[0]
            g.open(first)
            expect(g.bank.count >= first.answer.count, "bank holds the answer")
            let wrongKeys = g.bank.filter { !first.letters.contains($0.letter) }
            if wrongKeys.count >= first.answer.count {
                for k in wrongKeys.prefix(first.answer.count) { g.tapKey(k) }
                expect(g.lastWrong, "\(level.id) wrong answer flagged")
                expect(!g.solved.contains(first.id), "\(level.id) wrong answer not solved")
                expect(g.typed.allSatisfy { $0 == nil }, "\(level.id) wrong answer cleared")
            }
            // solve every word by typing the right letters from the bank
            for e in level.entries where !g.solved.contains(e.id) {
                g.open(e)
                for i in e.letters.indices where !g.isLocked(i) {
                    guard let k = g.bank.first(where: { $0.letter == e.letters[i] && !$0.used }) else {
                        expect(false, "\(level.id) \(e.id) letter \(e.letters[i]) missing from bank"); break
                    }
                    g.tapKey(k)
                }
                expect(g.solved.contains(e.id), "\(level.id) \(e.id) solved")
            }
            expect(g.isComplete, "\(level.id) complete")
            // crossing letters pre-filled: reopen a fresh engine, solve one word, open a crossing one
            let h = GameEngine(level: level)
            h.open(level.entries[0])
            for i in level.entries[0].letters.indices { h.tapKey(h.bank.first { $0.letter == level.entries[0].letters[i] && !$0.used }!) }
            if let cross = level.entries.dropFirst().first(where: { Set($0.cells).intersection(level.entries[0].cells).count > 0 && !h.solved.contains($0.id) }) {
                h.open(cross)
                expect(h.typed.contains { $0 != nil }, "\(level.id) crossing letter pre-filled")
            }
            print(level.id, "ok,", level.entries.count, "words")
        }
        print(fails == 0 ? "ALL PASS" : "\(fails) FAILED")
        exit(fails == 0 ? 0 : 1)
    }
}
