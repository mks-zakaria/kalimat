import SwiftUI

/// S02 — level packs.
struct PacksScreen: View {
    let packs: [Pack]
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.S.md) {
                ForEach(packs) { pack in
                    let open = store.isUnlocked(pack, in: packs)
                    Button { path.append(.levels(pack)) } label: {
                        PackCard(title: pack.titleAr, solved: store.solvedCount(pack),
                                 total: pack.levels.count, locked: !open)
                    }
                    .buttonStyle(.plain)
                    .disabled(!open)
                }
            }
            .padding(Theme.S.lg)
        }
        .background(Theme.C.bg.ignoresSafeArea())
        .navigationTitle("المجموعات")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { CoinBadge(coins: store.coins) } }
    }
}

/// S03 — levels of one pack.
struct LevelsScreen: View {
    let pack: Pack
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.S.md), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.S.lg) {
                HStack {
                    StarsView(stars: 1, size: 16)
                    Text("\(arNum(store.totalStars(pack))) / \(arNum(pack.levels.count * 3))")
                        .font(Theme.F.number).foregroundStyle(Theme.C.textMuted)
                    Spacer()
                }
                LazyVGrid(columns: columns, spacing: Theme.S.md) {
                    ForEach(pack.levels) { level in
                        let unlocked = store.isUnlocked(level, in: pack)
                        Button { path.append(.board(level, pack)) } label: {
                            LevelTile(number: level.number, state: state(level, unlocked))
                        }
                        .simultaneousGesture(TapGesture().onEnded { if !unlocked { SoundService.shared.play(.wrong) } })
                        .buttonStyle(.plain)
                        .disabled(!unlocked)
                        .accessibilityLabel("لغز \(arNum(level.number))")
                    }
                }
            }
            .padding(Theme.S.lg)
        }
        .background(Theme.C.bg.ignoresSafeArea())
        .navigationTitle(pack.titleAr)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func state(_ level: Level, _ unlocked: Bool) -> TileState {
        if store.isComplete(level.id) { return .solved(store.stars(for: level.id)) }
        return unlocked ? .open : .locked
    }
}
