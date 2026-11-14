import SwiftUI

@main
struct CrosswordApp: App {
    @State private var store = ProgressStore()
    private let packs = ContentStore.loadPacks()

    var body: some Scene {
        WindowGroup {
            RootView(packs: packs)
                .environment(store)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
        }
    }
}

enum Route: Hashable {
    case packs
    case levels(Pack)
    case board(Level, Pack)
}

struct RootView: View {
    let packs: [Pack]
    @Environment(ProgressStore.self) private var store
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(packs: packs, path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .packs:
                        PacksScreen(packs: packs, path: $path)
                    case .levels(let pack):
                        LevelsScreen(pack: pack, path: $path)
                    case .board(let level, let pack):
                        BoardScreen(level: level, pack: pack, path: $path)
                            .id(level.id)
                    }
                }
        }
        .tint(Theme.C.accent)
    }
}

/// First unfinished, unlocked level across all packs.
func nextLevel(in packs: [Pack], store: ProgressStore) -> (Level, Pack)? {
    for pack in packs where store.isUnlocked(pack, in: packs) {
        if let l = pack.levels.first(where: { !store.isComplete($0.id) && store.isUnlocked($0, in: pack) }) {
            return (l, pack)
        }
    }
    return nil
}
