import SwiftUI

/// Every primitive in every state, on one screen — the design-system check.
/// Sample clues here are placeholders written for this catalog only.
struct DesignCatalog: View {
    typealias Cell = CrosswordBoard.Cell

    var body: some View {
        VStack(spacing: Theme.S.lg) {
            TopBar(title: "لغز ٧") { CoinBadge(coins: 140) }

            // Board: "دبي" across (solved) crossing "عبرة" down (selected, last letter revealed).
            CrosswordBoard(
                rows: 4, cols: 5,
                letters: [Cell(row: 1, col: 0): "د", Cell(row: 1, col: 1): "ب", Cell(row: 1, col: 2): "ي",
                          Cell(row: 0, col: 1): "ع", Cell(row: 2, col: 1): "ر",
                          Cell(row: 3, col: 1): "ة", Cell(row: 3, col: 3): "ن"],
                states: [Cell(row: 1, col: 0): .solved, Cell(row: 1, col: 1): .solved, Cell(row: 1, col: 2): .solved,
                         Cell(row: 0, col: 1): .active, Cell(row: 2, col: 1): .active, Cell(row: 3, col: 1): .hint,
                         Cell(row: 2, col: 3): .empty, Cell(row: 3, col: 3): .hint],
                cellSize: 34)

            ClueCard(category: "جغرافيا الخليج", clue: "مدينة إماراتية فيها أطول برج في العالم")

            AnswerSlots(letters: ["د", "ب", nil, nil], states: [.typed, .revealed, .empty, .wrong])
            AnswerSlots(letters: ["د", "ب", "ي"], states: [.solved, .solved, .solved])

            HStack(spacing: Theme.S.sm) {
                HintButton(kind: .reveal, cost: 20)
                HintButton(kind: .remove, cost: 10, enabled: false)
            }

            LetterBank(keys: [("د", .used), ("ب", .used), ("ي", .normal), ("ة", .normal), ("س", .removed),
                              ("ع", .normal), ("ر", .normal), ("ق", .normal), ("ل", .normal), ("ء", .normal)])

            HStack(spacing: Theme.S.md) {
                LevelTile(number: 1, state: .solved(3))
                LevelTile(number: 2, state: .solved(1))
                LevelTile(number: 3, state: .open)
                LevelTile(number: 4, state: .locked)
            }

            PackCard(title: "الخليج ١", solved: 12, total: 30)
            PackCard(title: "معلومات عامة ٢", solved: 0, total: 30, locked: true)

            HStack(spacing: Theme.S.md) {
                PrimaryButton(title: "اللغز التالي")
                PrimaryButton(title: "شاهد إعلانًا +٥٠", secondary: true)
            }
        }
        .padding(Theme.S.lg)
        .background(Theme.C.bg)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
