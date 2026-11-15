import StoreKit
import SwiftUI

/// S04 + S05 on one screen: the crossword on top, the open word's clue,
/// answer slots, hints and letter keys below. Solving a word moves straight
/// to the next one (fewer taps than opening each clue separately).
/// S06 (level complete) is an overlay.
struct BoardScreen: View {
    let pack: Pack
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store
    @Environment(\.requestReview) private var requestReview
    @State private var engine: GameEngine
    @State private var shake = 0
    @State private var noCoins = false
    @State private var showComplete = false
    @State private var reward = 0
    @State private var alreadyDone = false      // replays earn no coins
    @State private var iqResult: IQResult?
    private let levelAtStart: Level

    init(level: Level, pack: Pack, path: Binding<[Route]>) {
        self.pack = pack
        self._path = path
        self.levelAtStart = level
        _engine = State(initialValue: GameEngine(level: level))
    }

    var body: some View {
        ZStack {
            SceneBackground(mood: .forPack(order: pack.order), duneHeight: 0.22)

            VStack(spacing: Theme.S.md) {
                SceneTopBar(title: "لغز \(arNum(engine.level.number))", back: { path.removeLast() }) {
                    TopBarActions()
                }

                GeometryReader { g in
                    CrosswordBoard(rows: engine.level.height, cols: engine.level.width,
                                   letters: letters, states: states, cellSize: cellSize(for: g.size),
                                   cursor: cursorCell) { cell in
                        open(at: CellPos(row: cell.row, col: cell.col))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, Theme.S.lg)

                if let entry = engine.current, !engine.isComplete {
                    dock(entry)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if showComplete {
                LevelComplete(stars: engine.stars, reward: reward, iq: iqResult, next: nextInPack) { next in
                    path.removeLast()
                    if let next { path.append(.board(next, pack)) }
                    // between levels only, and only if the frequency rules allow it
                    AdService.shared.levelFinished(levelNumber: engine.level.number)
                }
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: engine.current?.id)
        .animation(.easeOut(duration: 0.3), value: showComplete)
        .noCoinsCard(isPresented: $noCoins)
        .onAppear(perform: restore)
        .solveTiming(levelId: levelAtStart.id, running: !engine.isComplete)
        .onChange(of: engine.lastWrong) { _, wrong in
            if wrong {
                SoundService.shared.play(.wrong)
                withAnimation(.default) { shake += 1 }
            }
        }
        .onChange(of: engine.solved.count) { old, new in
            guard new > old else { return }
            SoundService.shared.play(.correct)
            if engine.isComplete { finish() }
            else {
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    if let next = engine.nextUnsolved(after: engine.current) { engine.open(next) }
                }
            }
        }
    }

    // MARK: dock (clue + slots + hints + keys)

    private func dock(_ entry: Entry) -> some View {
        VStack(spacing: Theme.S.md) {
            ClueCard(category: entry.category, clue: entry.clueAr)

            AnswerSlots(letters: engine.typed, states: slotStates) { i in
                if engine.typed[i] != nil && !engine.isLocked(i) { SoundService.shared.play(.undo) }
                engine.tapSlot(i)
            }
            .modifier(Shake(amount: CGFloat(shake)))

            HStack(spacing: Theme.S.sm) {
                Button { useHint(ProgressStore.revealCost, sound: .hint) { engine.revealLetter() } } label: {
                    HintButton(kind: .reveal, cost: ProgressStore.revealCost, enabled: engine.canReveal)
                }
                .disabled(!engine.canReveal)
                .accessibilityIdentifier("hint.reveal")
                Button { useHint(ProgressStore.removeCost, sound: .erase) { engine.removeDecoy() } } label: {
                    HintButton(kind: .remove, cost: ProgressStore.removeCost, enabled: engine.canRemoveDecoy)
                }
                .disabled(!engine.canRemoveDecoy)
                .accessibilityIdentifier("hint.remove")
            }
            .buttonStyle(PressStyle())

            keys
        }
        .padding(Theme.S.md)
        .padding(.bottom, Theme.S.sm)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(Theme.C.panel.opacity(0.97))
                .shadow(color: .black.opacity(0.25), radius: 16, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var keys: some View {
        let ks = engine.bank
        let half = (ks.count + 1) / 2
        return VStack(spacing: 6) {
            keyRow(ks[0..<half])
            keyRow(ks[half..<ks.count])
        }
    }

    private func keyRow(_ ks: ArraySlice<BankKey>) -> some View {
        HStack(spacing: 5) {
            ForEach(ks) { k in
                Button {
                    SoundService.shared.play(.key)
                    engine.tapKey(k)
                } label: {
                    LetterKey(letter: k.letter, state: k.removed ? .removed : (k.used ? .used : .normal))
                }
                .buttonStyle(PressStyle())
                .disabled(k.used || k.removed || engine.currentSolved)
                .accessibilityLabel(k.letter)
                .accessibilityIdentifier("key.\(k.id)")
                .accessibilityHidden(k.removed)          // a removed letter is gone for VoiceOver too
            }
        }
    }

    private var slotStates: [SlotState] {
        engine.typed.indices.map { i in
            if engine.currentSolved { return .solved }
            if engine.isRevealed(i) { return .revealed }
            if engine.isLocked(i) { return .solved }
            if engine.lastWrong { return .wrong }
            return engine.typed[i] == nil ? .empty : .typed
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

    // MARK: board

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
        alreadyDone = store.isComplete(id)
        if fresh.isComplete { showComplete = true }
        else if let first = fresh.nextUnsolved(after: nil) { fresh.open(first) }
    }

    private func finish() {
        reward = alreadyDone ? 0 : (engine.stars == 3 ? 10 : 5)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            if reward > 0 { store.earn(reward) }
            iqResult = store.recordIQ(engine.level.id, expected: IQ.expectedSeconds(engine.level, mode: .crossword),
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

    private var letters: [CrosswordBoard.Cell: String] {
        var m: [CrosswordBoard.Cell: String] = [:]
        for (c, v) in engine.filled { m[CrosswordBoard.Cell(row: c.row, col: c.col)] = v }
        // typed (not yet checked) letters show on the board too
        if let e = engine.current {
            for (i, c) in e.cells.enumerated() where engine.filled[c] == nil {
                if let t = engine.typed[safe: i] ?? nil { m[CrosswordBoard.Cell(row: c.row, col: c.col)] = t }
            }
        }
        return m
    }

    private var states: [CrosswordBoard.Cell: CellState] {
        var s: [CrosswordBoard.Cell: CellState] = [:]
        let active = Set(engine.current?.cells ?? [])
        for c in engine.allCells {
            let k = CrosswordBoard.Cell(row: c.row, col: c.col)
            if engine.revealed.contains(c) { s[k] = .hint }
            else if engine.filled[c] != nil { s[k] = .solved }
            else if active.contains(c) { s[k] = .active }
            else { s[k] = .empty }
        }
        return s
    }

    private var cursorCell: CrosswordBoard.Cell? {
        guard let e = engine.current, let i = engine.typed.firstIndex(where: { $0 == nil }) else { return nil }
        return CrosswordBoard.Cell(row: e.cells[i].row, col: e.cells[i].col)
    }

    private func cellSize(for size: CGSize) -> CGFloat {
        let w = (size.width - CGFloat(engine.level.width - 1) * Theme.S.cellGap) / CGFloat(engine.level.width)
        let h = (size.height - CGFloat(engine.level.height - 1) * Theme.S.cellGap) / CGFloat(engine.level.height)
        return max(24, min(Theme.S.cellMax + 6, w, h))
    }

    private func open(at cell: CellPos) {
        guard let e = engine.entryToOpen(at: cell, previous: engine.current) else {
            SoundService.shared.play(.tap)
            return
        }
        SoundService.shared.play(.open)
        engine.open(e)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// Horizontal shake for a wrong answer.
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}

/// S06 — level complete: dimmed scene, banner, stars popping in, coin reward, confetti.
struct LevelComplete: View {
    let stars: Int
    let reward: Int
    var iq: IQResult? = nil
    let next: Level?
    let go: (Level?) -> Void
    @State private var shown = 0
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            Confetti()
            VStack(spacing: Theme.S.lg) {
                Text(stars == 3 ? "ممتاز!" : "أحسنت!")
                    .font(Theme.arabic(40, .bold))
                    .foregroundStyle(Theme.C.onGold)
                    .padding(.horizontal, Theme.S.xxl).padding(.vertical, Theme.S.xs)
                    .background(LinearGradient(colors: [Color(hex: 0xFFD978), Theme.C.goldShade], startPoint: .top, endPoint: .bottom),
                                in: Capsule())
                    .overlay(Capsule().stroke(Theme.C.goldEdge, lineWidth: 2))
                    .offset(y: -10)

                HStack(spacing: Theme.S.md) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: i == 1 ? 58 : 44, weight: .bold))
                            .foregroundStyle(i < shown ? Theme.C.gold : .black.opacity(0.18))
                            .shadow(color: i < shown ? Theme.C.goldEdge : .clear, radius: 0, y: 3)
                            .scaleEffect(i < shown ? 1 : 0.6)
                            .offset(y: i == 1 ? -10 : 0)
                    }
                }

                Text(stars == 3 ? "حللت اللغز بدون أي مساعدة!" : "حلّه بمساعدات أقل لتنال ٣ نجوم")
                    .font(Theme.F.body).foregroundStyle(Theme.C.panelMuted)

                if let iq { IQResultView(result: iq) }

                if reward > 0 {
                    HStack(spacing: 6) {
                        Text("+\(arNum(reward))").font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.C.onGold)
                        CoinIcon(size: 26)
                    }
                    .padding(.horizontal, Theme.S.lg).padding(.vertical, Theme.S.xs)
                    .background(Theme.C.gold.opacity(0.3), in: Capsule())
                }

                Button {
                    SoundService.shared.play(.tap)
                    go(next)
                } label: {
                    GameButton(title: next == nil ? "العودة للمجموعة" : "اللغز التالي",
                               icon: next == nil ? "square.grid.2x2.fill" : "arrow.left", style: .primary)
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("complete.next")
            }
            .padding(Theme.S.xl)
            .background(Theme.C.panel, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.C.gold, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(Theme.S.xl)
            .scaleEffect(appear ? 1 : 0.7)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { appear = true }
            Task {
                for i in 1...max(stars, 1) where i <= stars {
                    try? await Task.sleep(for: .milliseconds(i == 1 ? 650 : 380))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { shown = i }
                }
            }
        }
    }
}
