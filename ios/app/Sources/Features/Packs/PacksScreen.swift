import SwiftUI

/// S02 — level packs, each with its own scene.
struct PacksScreen: View {
    let packs: [Pack]
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store

    var body: some View {
        ZStack {
            SceneBackground(mood: .night, duneHeight: 0.2)
            VStack(spacing: 0) {
                SceneTopBar(title: "المجموعات", back: { path.removeLast() }) { CoinBadge(coins: store.coins) }
                ScrollView {
                    VStack(spacing: Theme.S.lg) {
                        ForEach(packs) { pack in
                            let open = store.isUnlocked(pack, in: packs)
                            Button {
                                if open { path.append(.levels(pack)) } else { SoundService.shared.play(.wrong) }
                            } label: {
                                PackCard(title: pack.titleAr, solved: store.solvedCount(pack), total: pack.levels.count,
                                         stars: store.totalStars(pack), order: pack.order, locked: !open)
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                    .padding(Theme.S.lg)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// S03 — levels of one pack as medallions on a winding path.
struct LevelsScreen: View {
    let pack: Pack
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store

    var body: some View {
        let nextId = pack.levels.first { !store.isComplete($0.id) && store.isUnlocked($0, in: pack) }?.id
        ZStack {
            SceneBackground(mood: .forPack(order: pack.order), duneHeight: 0.25)
            VStack(spacing: 0) {
                SceneTopBar(title: pack.titleAr, back: { path.removeLast() }) { CoinBadge(coins: store.coins) }

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
                                if unlocked { path.append(.board(level, pack)) } else { SoundService.shared.play(.wrong) }
                            } label: {
                                LevelMedallion(number: level.number, state: state(level, unlocked), isNext: level.id == nextId)
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityLabel("لغز \(arNum(level.number))")
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
    }

    private func state(_ level: Level, _ unlocked: Bool) -> TileState {
        if store.isComplete(level.id) { return .solved(store.stars(for: level.id)) }
        return unlocked ? .open : .locked
    }
}
