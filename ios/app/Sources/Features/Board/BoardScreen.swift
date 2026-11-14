import SwiftUI

/// S04 — the crossword. Tap a word to open its clue (S05). S06 shows when complete.
struct BoardScreen: View {
    let pack: Pack
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store
    @State private var engine: GameEngine
    @State private var selected: Entry?
    @State private var showClue = false
    private let levelAtStart: Level

    init(level: Level, pack: Pack, path: Binding<[Route]>) {
        self.pack = pack
        self._path = path
        self.levelAtStart = level
        _engine = State(initialValue: GameEngine(level: level))
    }

    var body: some View {
        VStack(spacing: Theme.S.lg) {
            Spacer(minLength: 0)
            GeometryReader { g in
                CrosswordBoard(rows: engine.level.height, cols: engine.level.width,
                               letters: letters, states: states, cellSize: cellSize(for: g.size)) { cell in
                    open(at: CellPos(row: cell.row, col: cell.col))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer(minLength: 0)

            if engine.isComplete {
                LevelComplete(stars: engine.stars, next: nextInPack) { next in
                    path.removeLast()
                    if let next { path.append(.board(next, pack)) }
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("اضغط على أي خانة لترى سؤالها").font(Theme.F.body).foregroundStyle(Theme.C.textMuted)
            }
        }
        .padding(Theme.S.lg)
        .background(Theme.C.bg.ignoresSafeArea())
        .navigationTitle("لغز \(arNum(engine.level.number))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { CoinBadge(coins: store.coins) } }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: engine.isComplete)
        .sheet(isPresented: $showClue) {
            ClueScreen(engine: engine)
                .environment(store)
                .environment(\.layoutDirection, .rightToLeft)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear(perform: restore)
        .onChange(of: engine.isComplete) { _, done in
            guard done else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(650))   // after the word's own "correct"
                SoundService.shared.play(.complete)
                for _ in 0..<engine.stars {
                    try? await Task.sleep(for: .milliseconds(380))
                    SoundService.shared.play(.star)
                }
            }
        }
    }

    private var nextInPack: Level? {
        guard let i = pack.levels.firstIndex(of: engine.level), i + 1 < pack.levels.count else { return nil }
        return pack.levels[i + 1]
    }

    private func restore() {
        guard engine.onProgress == nil else { return }
        let fresh = GameEngine(level: levelAtStart, saved: store.progress(for: levelAtStart.id))
        let id = levelAtStart.id
        fresh.onProgress = { [store] p in store.update(id, p) }
        engine = fresh
    }

    private var letters: [CrosswordBoard.Cell: String] {
        Dictionary(uniqueKeysWithValues: engine.filled.map { (CrosswordBoard.Cell(row: $0.key.row, col: $0.key.col), $0.value) })
    }

    private var states: [CrosswordBoard.Cell: CellState] {
        var s: [CrosswordBoard.Cell: CellState] = [:]
        let active = Set(showClue ? (selected?.cells ?? []) : [])
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
        guard let e = engine.entryToOpen(at: cell, previous: selected) else {
            SoundService.shared.play(.tap)
            return
        }
        SoundService.shared.play(.open)
        selected = e
        engine.open(e)
        showClue = true
    }
}

/// S06 — level complete.
struct LevelComplete: View {
    let stars: Int
    let next: Level?
    let go: (Level?) -> Void

    var body: some View {
        VStack(spacing: Theme.S.md) {
            Text("أحسنت! اكتمل اللغز").font(Theme.F.title).foregroundStyle(Theme.C.success)
            StarsView(stars: stars, size: 28)
            Text(stars == 3 ? "بدون أي مساعدة!" : "حاول حله بمساعدات أقل لتنال ٣ نجوم")
                .font(Theme.F.caption).foregroundStyle(Theme.C.textMuted)
            Button { go(next) } label: {
                PrimaryButton(title: next == nil ? "العودة للمجموعة" : "اللغز التالي")
            }
        }
        .padding(Theme.S.lg)
        .background(Theme.C.surface, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .cardShadow()
    }
}
