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
                .onAppear { SoundService.shared.enabled = store.soundOn }
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
        #if DEBUG
        .onAppear { DebugLaunch.apply(packs: packs, path: &path) }
        #endif
        .onChange(of: path) { old, new in
            if new.count > old.count { SoundService.shared.play(.open) }
        }
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

#if DEBUG
/// Simulator screenshots only (never in release builds): `-screen packs|levels|board`.
enum DebugLaunch {
    static func apply(packs: [Pack], path: inout [Route]) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count, let pack = packs.first else { return }
        switch args[i + 1] {
        case "packs": path = [.packs]
        case "levels": path = [.packs, .levels(pack)]
        case "board": path = [.packs, .levels(pack), .board(pack.levels[0], pack)]
        case "level":   // -screen level -level p06-012
            if let j = args.firstIndex(of: "-level"), j + 1 < args.count,
               let p = packs.first(where: { $0.levels.contains { $0.id == args[j + 1] } }),
               let l = p.levels.first(where: { $0.id == args[j + 1] }) {
                path = [.packs, .levels(p), .board(l, p)]
            }
        default: break
        }
    }
}
#endif
