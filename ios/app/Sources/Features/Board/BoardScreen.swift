import SwiftUI

/// S04 — the crossword. Tap a word to open its clue (S05).
struct BoardScreen: View {
    @State private var engine: GameEngine
    @State private var selected: Entry?
    @State private var showClue = false
    var onNext: (() -> Void)?

    init(level: Level, onNext: (() -> Void)? = nil) {
        _engine = State(initialValue: GameEngine(level: level))
        self.onNext = onNext
    }

    var body: some View {
        VStack(spacing: Theme.S.lg) {
            TopBar(title: "لغز \(arNum(engine.level.number))") {
                Text("\(arNum(engine.solved.count)) / \(arNum(engine.level.entries.count))")
                    .font(Theme.F.number).foregroundStyle(Theme.C.textMuted)
            }

            Spacer(minLength: 0)
            GeometryReader { g in
                let size = cellSize(for: g.size)
                CrosswordBoard(rows: engine.level.height, cols: engine.level.width,
                               letters: letters, states: states, cellSize: size) { cell in
                    open(at: CellPos(row: cell.row, col: cell.col))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer(minLength: 0)

            if engine.isComplete {
                VStack(spacing: Theme.S.md) {
                    Text("أحسنت! اكتمل اللغز").font(Theme.F.title).foregroundStyle(Theme.C.success)
                    if let onNext { Button(action: onNext) { PrimaryButton(title: "اللغز التالي") } }
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("اضغط على أي خانة لترى سؤالها").font(Theme.F.body).foregroundStyle(Theme.C.textMuted)
            }
        }
        .padding(Theme.S.lg)
        .background(Theme.C.bg.ignoresSafeArea())
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: engine.isComplete)
        .sheet(isPresented: $showClue) {
            ClueScreen(engine: engine)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var letters: [CrosswordBoard.Cell: String] {
        Dictionary(uniqueKeysWithValues: engine.filled.map { (CrosswordBoard.Cell(row: $0.key.row, col: $0.key.col), $0.value) })
    }

    private var states: [CrosswordBoard.Cell: CellState] {
        var s: [CrosswordBoard.Cell: CellState] = [:]
        let active = Set(selected.map { showClue ? $0.cells : [] } ?? [])
        for c in engine.allCells {
            let k = CrosswordBoard.Cell(row: c.row, col: c.col)
            if engine.revealed.contains(c) { s[k] = .hint }
            else if engine.filled[c] != nil { s[k] = .solved }
            else if active.contains(c) { s[k] = .active }
            else { s[k] = .empty }
        }
        return s
    }

    private func cellSize(for size: CGSize) -> CGFloat {
        let w = (size.width - CGFloat(engine.level.width - 1) * Theme.S.cellGap) / CGFloat(engine.level.width)
        let h = (size.height - CGFloat(engine.level.height - 1) * Theme.S.cellGap) / CGFloat(engine.level.height)
        return max(24, min(Theme.S.cellMax + 8, w, h))
    }

    private func open(at cell: CellPos) {
        guard let e = engine.entryToOpen(at: cell, previous: selected) else { return }
        selected = e
        engine.open(e)
        showClue = true
    }
}
