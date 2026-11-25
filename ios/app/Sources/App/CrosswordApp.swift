import SwiftUI

@main
struct CrosswordApp: App {
    @State private var store: ProgressStore = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-reset") {       // UI tests start from a clean save
            try? FileManager.default.removeItem(at: ProgressStore.defaultURL)
        }
        #endif
        return ProgressStore()
    }()
    private let packs: [Pack]
    private let wsPacks: [Pack]

    init() {
        let p = ContentStore.loadPacks()
        packs = p
        wsPacks = WordSearchContent.packs(from: p)      // regrouped once, deterministically
    }

    var body: some Scene {
        WindowGroup {
            RootView(packs: packs, wsPacks: wsPacks)
                .environment(store)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .onAppear {
                    SoundService.shared.enabled = store.soundOn
                    AdService.shared.start()
                }
        }
    }
}

enum Route: Hashable {
    case packs(GameMode)
    case levels(Pack)
    case board(Level, Pack)
}

struct RootView: View {
    let packs: [Pack]
    let wsPacks: [Pack]
    @Environment(ProgressStore.self) private var store
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(packs: packs, wsPacks: wsPacks, path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .packs(let mode):
                        PacksScreen(packs: packs, wsPacks: wsPacks, mode: mode, path: $path)
                    case .levels(let pack):
                        LevelsScreen(pack: pack, path: $path)
                    case .board(let level, let pack):
                        if pack.isWordSearch {
                            WordSearchScreen(level: level, pack: pack, path: $path)
                                .id(level.id)
                        } else {
                            BoardScreen(level: level, pack: pack, path: $path)
                                .id(level.id)
                        }
                    }
                }
        }
        .tint(Theme.C.accent)
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-demo") { store.seedDemo(packs: packs, wsPacks: wsPacks) }
            DebugLaunch.apply(packs: packs, wsPacks: wsPacks, path: &path)
        }
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
/// Simulator screenshots and UI tests only (never in release builds):
/// `-screen packs|levels|board|wspacks|wslevels`, or `-screen level -level <id>` (crossword
/// ids like p06-012, word-search ids like p01-w003).
enum DebugLaunch {
    static func apply(packs: [Pack], wsPacks: [Pack], path: inout [Route]) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count,
              let pack = packs.first, let ws = wsPacks.first else { return }
        switch args[i + 1] {
        case "packs": path = [.packs(.crossword)]
        case "levels": path = [.packs(.crossword), .levels(pack)]
        case "board": path = [.packs(.crossword), .levels(pack), .board(pack.levels[0], pack)]
        case "wspacks": path = [.packs(.wordSearch)]
        case "wslevels": path = [.packs(.wordSearch), .levels(ws)]
        case "level":
            let all = packs + wsPacks
            if let j = args.firstIndex(of: "-level"), j + 1 < args.count,
               let p = all.first(where: { $0.levels.contains { $0.id == args[j + 1] } }),
               let l = p.levels.first(where: { $0.id == args[j + 1] }) {
                path = [.packs(p.isWordSearch ? .wordSearch : .crossword), .levels(p), .board(l, p)]
            }
        default: break
        }
    }
}
#endif
