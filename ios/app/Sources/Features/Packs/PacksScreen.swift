import SwiftUI

/// S02 — level packs, each with its own scene.
struct PacksScreen: View {
    let packs: [Pack]
    let wsPacks: [Pack]
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store
    @State private var toast: String?
    @State private var mode: GameMode

    init(packs: [Pack], wsPacks: [Pack], mode: GameMode, path: Binding<[Route]>) {
        self.packs = packs
        self.wsPacks = wsPacks
        self._path = path
        _mode = State(initialValue: mode)
    }

    var body: some View {
        let packs = mode == .crossword ? self.packs : wsPacks
        ZStack {
            SceneBackground(mood: .night, duneHeight: 0.2)
            VStack(spacing: 0) {
                SceneTopBar(title: "المجموعات", back: { path.removeLast() }) { TopBarActions() }
                ModePicker(mode: $mode).padding(.horizontal, Theme.S.lg).padding(.top, Theme.S.sm)
                ScrollView {
                    VStack(spacing: Theme.S.lg) {
                        ForEach(packs) { pack in
                            let open = store.isUnlocked(pack, in: packs)
                            Button {
                                if open { path.append(.levels(pack)) } else {
                                    SoundService.shared.play(.wrong)
                                    toast = "أكمل المجموعة السابقة لفتح هذه المجموعة"
                                }
                            } label: {
                                PackCard(title: pack.titleAr, solved: store.solvedCount(pack), total: pack.levels.count,
                                         stars: store.totalStars(pack), order: pack.order, locked: !open)
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("pack.\(pack.id)")
                        }
                    }
                    .padding(Theme.S.lg)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }
}

/// S03 — levels of one pack as medallions on a winding path.
struct LevelsScreen: View {
    let pack: Pack
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store
    @State private var toast: String?

    var body: some View {
        let nextId = pack.levels.first { !store.isComplete($0.id) && store.isUnlocked($0, in: pack) }?.id
        ZStack {
            SceneBackground(mood: .forPack(order: pack.order), duneHeight: 0.25)
            VStack(spacing: 0) {
                SceneTopBar(title: pack.titleAr, back: { path.removeLast() }) { TopBarActions() }

                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.C.gold)
                    Text("\(arNum(store.totalStars(pack))) / \(arNum(pack.levels.count * 3))")
                        .font(Theme.F.number).foregroundStyle(.white)
                }
                .padding(.horizontal, Theme.S.md).padding(.vertical, 6)
                .background(Theme.C.coinPill.opacity(0.55), in: Capsule())
                .padding(.top, Theme.S.sm)

                ScrollView {
                    VStack(spacing: Theme.S.md) {
                        ForEach(Array(pack.levels.enumerated()), id: \.element.id) { i, level in
                            let unlocked = store.isUnlocked(level, in: pack)
                            Button {
                                if unlocked { path.append(.board(level, pack)) } else {
                                    SoundService.shared.play(.wrong)
                                    toast = "أكمل اللغز السابق أولًا"
                                }
                            } label: {
                                LevelMedallion(number: level.number, state: state(level, unlocked), isNext: level.id == nextId)
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityLabel("لغز \(arNum(level.number))")
                            .accessibilityIdentifier("level.\(level.id)")
                            // winding path: shift left / centre / right
                            .offset(x: [0, 70, 0, -70][i % 4])
                        }
                    }
                    .padding(.vertical, Theme.S.xl)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }

    private func state(_ level: Level, _ unlocked: Bool) -> TileState {
        if store.isComplete(level.id) { return .solved(store.stars(for: level.id)) }
        return unlocked ? .open : .locked
    }
}

/// Switch between the two ways to play.
struct ModePicker: View {
    @Binding var mode: GameMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach([GameMode.crossword, .wordSearch], id: \.self) { m in
                Button {
                    guard m != mode else { return }
                    SoundService.shared.play(.tap)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { mode = m }
                } label: {
                    Text(m.title)
                        .font(Theme.arabic(16, .bold))
                        .foregroundStyle(m == mode ? Theme.C.onGold : .white)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(m == mode ? Theme.C.gold : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(m == .crossword ? "mode.crossword" : "mode.wordsearch")
                .accessibilityAddTraits(m == mode ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.C.coinPill.opacity(0.6), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
    }
}
