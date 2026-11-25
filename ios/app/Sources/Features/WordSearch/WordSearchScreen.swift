import StoreKit
import SwiftUI

/// S08 — word search: a square of letters on top, the clues below. Draw a straight line
/// (across, down or diagonal) over an answer, or tap its first letter then its last.
struct WordSearchScreen: View {
    let pack: Pack
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store
    @Environment(\.requestReview) private var requestReview
    @State private var engine: WordSearchEngine
    @State private var selectedId: String?          // clue the hints apply to
    @State private var shake = 0
    @State private var noCoins = false
    @State private var showComplete = false
    @State private var reward = 0
    @State private var alreadyDone = false
    @State private var lastFound: String?
    @State private var iqResult: IQResult?
    private let levelAtStart: Level

    init(level: Level, pack: Pack, path: Binding<[Route]>) {
        self.pack = pack
        self._path = path
        self.levelAtStart = level
        _engine = State(initialValue: WordSearchEngine(level: level))
    }

    var body: some View {
        ZStack {
            SceneBackground(mood: .forPack(order: pack.order), duneHeight: 0.22)

            VStack(spacing: Theme.S.md) {
                SceneTopBar(title: "كلمات مخفية · \(arNum(engine.level.number))", back: { path.removeLast() }) {
                    TopBarActions()
                }

                GeometryReader { g in
                    let side = min(g.size.width, g.size.height)
                    LetterGrid(puzzle: engine.puzzle, found: engine.found,
                               starts: Set(engine.level.entries.filter { engine.shownStarts.contains($0.id) && !engine.isFound($0) }
                                .compactMap { engine.startCell(of: $0) }),
                               side: side, onSelect: select)
                        .frame(width: side, height: side)
                        .modifier(Shake(amount: CGFloat(shake)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, Theme.S.lg)

                dock
            }

            if showComplete {
                LevelComplete(stars: engine.stars, reward: reward, iq: iqResult, next: nextInPack) { next in
                    path.removeLast()
                    if let next { path.append(.board(next, pack)) }
                    AdService.shared.levelFinished(levelNumber: engine.level.number)
                }
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeOut(duration: 0.3), value: showComplete)
        .noCoinsCard(isPresented: $noCoins)
        .onAppear(perform: restore)
        .solveTiming(levelId: levelAtStart.id, running: !engine.isComplete)
    }

    // MARK: dock (hints + clues)

    private var target: Entry? {
        engine.level.entries.first { $0.id == selectedId && !engine.isFound($0) } ?? engine.firstUnfound
    }

    private var dock: some View {
        VStack(spacing: Theme.S.sm) {
            HStack(spacing: Theme.S.sm) {
                let t = target
                Button { useHint(ProgressStore.revealCost, sound: .hint) { if let t { engine.showWord(t) } } } label: {
                    HintButton(kind: .reveal, cost: ProgressStore.revealCost, enabled: t.map(engine.canShowWord) ?? false,
                               title: "كشف الكلمة")
                }
                .disabled(!(t.map(engine.canShowWord) ?? false))
                .accessibilityIdentifier("ws.hint.word")
                Button { useHint(ProgressStore.removeCost, sound: .hint) { if let t { engine.showStart(t) } } } label: {
                    HintButton(kind: .remove, cost: ProgressStore.removeCost, enabled: t.map(engine.canShowStart) ?? false,
                               title: "أول حرف", icon: "scope")
                }
                .disabled(!(t.map(engine.canShowStart) ?? false))
                .accessibilityIdentifier("ws.hint.start")
            }
            .buttonStyle(PressStyle())

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(engine.level.entries.enumerated()), id: \.element.id) { i, e in
                        clueRow(e, index: i)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: 260)
        }
        .readableWidth()
        .padding(Theme.S.md)
        .padding(.bottom, Theme.S.sm)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(Theme.C.panel.opacity(0.97))
                .shadow(color: .black.opacity(0.25), radius: 16, y: -4)
                .ignoresSafeArea(edges: [.bottom, .horizontal])
        )
    }

    private func clueRow(_ e: Entry, index: Int) -> some View {
        let done = engine.isFound(e)
        let isTarget = target?.id == e.id
        let cat = Category.of(e.category)
        let count = WordSearchGenerator.letters(e).count
        return Button {
            guard !done else { return }
            SoundService.shared.play(.tap)
            selectedId = e.id
        } label: {
            HStack(spacing: Theme.S.sm) {
                Image(systemName: done ? "checkmark.circle.fill" : cat.icon)
                    .foregroundStyle(done ? Theme.C.success : cat.color)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(e.clueAr)
                        .font(Theme.arabic(16, .bold))
                        .foregroundStyle(done ? Theme.C.panelMuted : Theme.C.panelText)
                        .strikethrough(done, color: Theme.C.panelMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if done || engine.shownWords.contains(e.id) {
                        Text(e.answer).font(Theme.arabic(15, .bold))
                            .foregroundStyle(done ? Theme.C.success : Theme.C.turquoise)
                    }
                }
                Spacer(minLength: 0)
                Text(lettersLabel(count)).font(Theme.F.caption).foregroundStyle(Theme.C.panelMuted)
                    .lineLimit(1).fixedSize()
            }
            .padding(.horizontal, Theme.S.md).padding(.vertical, Theme.S.sm)
            .background(isTarget ? Theme.C.gold.opacity(0.28) : Theme.C.tile,
                        in: RoundedRectangle(cornerRadius: Theme.R.key))
            .overlay(RoundedRectangle(cornerRadius: Theme.R.key)
                .stroke(isTarget ? Theme.C.goldEdge : Theme.C.tileEdge.opacity(0.35), lineWidth: isTarget ? 2 : 1))
            .scaleEffect(lastFound == e.id ? 1.04 : 1)
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("ws.clue.\(index)")
        .accessibilityValue(done ? "تم" : "")
        .accessibilityAddTraits(isTarget ? .isSelected : [])
    }

    /// Arabic number agreement: حرفان، ٣–١٠ حروف، ١١+ حرفًا.
    private func lettersLabel(_ n: Int) -> String {
        n == 2 ? "حرفان" : (3...10).contains(n) ? "\(arNum(n)) حروف" : "\(arNum(n)) حرفًا"
    }

    // MARK: actions

    private func select(_ cells: [CellPos]) {
        switch engine.select(cells) {
        case .found(let e):
            SoundService.shared.play(.correct)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { lastFound = e.id }
            Task { try? await Task.sleep(for: .milliseconds(400)); withAnimation { lastFound = nil } }
            if selectedId == e.id { selectedId = nil }
            if engine.isComplete { finish() }
        case .wrong:
            SoundService.shared.play(.wrong)
            withAnimation(.default) { shake += 1 }
        case .tooShort:
            break
        }
    }

    private func useHint(_ cost: Int, sound: SoundService.Sound, _ action: () -> Void) {
        guard store.spend(cost) else {
            SoundService.shared.play(.wrong)
            noCoins = true
            return
        }
        SoundService.shared.play(.coin)
        SoundService.shared.play(sound)
        action()
    }

    private var nextInPack: Level? {
        guard let i = pack.levels.firstIndex(of: engine.level), i + 1 < pack.levels.count else { return nil }
        return pack.levels[i + 1]
    }

    private func restore() {
        guard engine.onProgress == nil else { return }
        let id = levelAtStart.id
        let fresh = WordSearchEngine(level: levelAtStart, saved: store.progress(for: id))
        fresh.onProgress = { [store] p in store.update(id, p) }
        engine = fresh
        alreadyDone = store.isComplete(id)
        if fresh.isComplete { showComplete = true }
    }

    private func finish() {
        reward = alreadyDone ? 0 : (engine.stars == 3 ? 10 : 5)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            if reward > 0 { store.earn(reward) }
            iqResult = store.recordIQ(engine.level.id,
                                      expected: IQ.expectedSeconds(engine.level, mode: .wordSearch, gridSize: engine.puzzle.size),
                                      hints: engine.hintsUsed)
            let firstEverFinish = store.file.levels.values.filter { $0.completedAt != nil }.count <= 1
            showComplete = true
            if firstEverFinish {
                // ATT once, after the first finished level, straight from this moment (⛔1)
                Task { try? await Task.sleep(for: .seconds(2.5)); AdService.shared.requestTrackingIfNeeded() }
            }
            try? await Task.sleep(for: .milliseconds(300))
            SoundService.shared.play(.complete)
            for _ in 0..<engine.stars {
                try? await Task.sleep(for: .milliseconds(380))
                SoundService.shared.play(.star)
            }
            // rating prompt: after real play only (8th / 30th / 80th level), once per version
            if store.shouldAskForReview() {
                try? await Task.sleep(for: .seconds(2))
                requestReview()
            }
        }
    }
}

/// The letter square. Laid out left-to-right in absolute coordinates with column 0 on the
/// RIGHT, so a word placed "across" reads right to left as Arabic does.
struct LetterGrid: View {
    let puzzle: WordSearchPuzzle
    let found: [String: [CellPos]]
    let starts: Set<CellPos>
    let side: CGFloat
    let onSelect: ([CellPos]) -> Void

    @State private var dragStart: CellPos?
    @State private var dragEnd: CellPos?
    @State private var tapStart: CellPos?

    private static let palette: [Color] = [
        Color(hex: 0x2A9D8F), Color(hex: 0xE76F51), Color(hex: 0x6A4C93), Color(hex: 0xE9A23B),
        Color(hex: 0x3D7DCA), Color(hex: 0xC2185B), Color(hex: 0x558B2F), Color(hex: 0x8D6E63),
    ]

    var body: some View {
        let n = puzzle.size
        let s = side / CGFloat(n)
        ZStack {
            RoundedRectangle(cornerRadius: Theme.R.card).fill(Theme.C.panel)
                .overlay(RoundedRectangle(cornerRadius: Theme.R.card).stroke(Theme.C.gold, lineWidth: 2))
                .cardShadow()

            // found words: one coloured band each
            ForEach(Array(found.keys.sorted().enumerated()), id: \.element) { i, id in
                if let cells = found[id], let a = cells.first, let b = cells.last {
                    band(a, b, s: s, color: Self.palette[i % Self.palette.count].opacity(0.42))
                }
            }
            // the line being drawn (or the first tap)
            if let a = dragStart ?? tapStart {
                band(a, dragEnd ?? a, s: s, color: Theme.C.gold.opacity(0.6))
            }
            // hint: first letter of a word
            ForEach(Array(starts), id: \.self) { c in
                Circle().stroke(Theme.C.turquoise, lineWidth: 3)
                    .frame(width: s * 0.86, height: s * 0.86)
                    .position(center(c, s: s))
            }

            ForEach(0..<n, id: \.self) { r in
                ForEach(0..<n, id: \.self) { c in
                    let cell = CellPos(row: r, col: c)
                    Text(puzzle.letter(cell))
                        .font(Theme.arabic(min(30, s * 0.56), .bold))
                        .foregroundStyle(Theme.C.tileText)
                        .frame(width: s, height: s)
                        .position(center(cell, s: s))
                        .accessibilityIdentifier("ws.cell.\(r).\(c)")
                }
            }
        }
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let a = dragStart ?? cell(at: v.startLocation, s: s, n: n)
                    if dragStart == nil { dragStart = a; SoundService.shared.play(.key) }
                    let end = snapped(from: a, to: v.location, s: s, n: n)
                    if end != dragEnd { dragEnd = end }
                }
                .onEnded { v in
                    defer { dragStart = nil; dragEnd = nil }
                    guard let a = dragStart else { return }
                    let moved = hypot(v.translation.width, v.translation.height) > s * 0.45
                    if moved, let end = dragEnd, end != a, let line = WordSearchEngine.line(from: a, to: end) {
                        tapStart = nil
                        onSelect(line)
                    } else {
                        tap(a)
                    }
                }
        )
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ws.grid")
    }

    /// Tap the first letter, then the last: same as drawing the line.
    private func tap(_ c: CellPos) {
        if let a = tapStart {
            tapStart = nil
            if a != c, let line = WordSearchEngine.line(from: a, to: c) { onSelect(line) }
            else if a != c { tapStart = c }
        } else {
            tapStart = c
        }
    }

    private func center(_ c: CellPos, s: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(puzzle.size - 1 - c.col) + 0.5) * s, y: (CGFloat(c.row) + 0.5) * s)
    }

    private func cell(at p: CGPoint, s: CGFloat, n: Int) -> CellPos {
        let col = n - 1 - min(n - 1, max(0, Int(p.x / s)))
        let row = min(n - 1, max(0, Int(p.y / s)))
        return CellPos(row: row, col: col)
    }

    /// Snaps the finger to the nearest of the 8 straight directions, clipped to the grid.
    private func snapped(from a: CellPos, to p: CGPoint, s: CGFloat, n: Int) -> CellPos {
        let o = center(a, s: s)
        let dx = p.x - o.x, dy = p.y - o.y
        guard hypot(dx, dy) > s * 0.35 else { return a }
        let angle = atan2(dy, dx)
        let step = Int((angle / (.pi / 4)).rounded())          // -4...4
        let screen = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
        let (sx, sy) = screen[(step + 8) % 8]
        var len = Int((max(abs(dx), abs(dy)) / s).rounded())
        while len > 0 {
            let r = a.row + sy * len, c = a.col - sx * len      // screen x grows leftward in cols
            if (0..<n).contains(r) && (0..<n).contains(c) { return CellPos(row: r, col: c) }
            len -= 1
        }
        return a
    }

    private func band(_ a: CellPos, _ b: CellPos, s: CGFloat, color: Color) -> some View {
        let p = center(a, s: s), q = center(b, s: s)
        let length = hypot(q.x - p.x, q.y - p.y) + s * 0.82
        return Capsule().fill(color)
            .frame(width: length, height: s * 0.82)
            .rotationEffect(.radians(atan2(q.y - p.y, q.x - p.x)))
            .position(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
            .allowsHitTesting(false)
    }
}
