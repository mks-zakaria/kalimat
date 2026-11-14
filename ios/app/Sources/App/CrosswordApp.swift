import SwiftUI

@main
struct CrosswordApp: App {
    var body: some Scene {
        WindowGroup {
            SliceRoot()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
        }
    }
}

/// M0 vertical slice: plays the bundled levels in order. S01–S03 come in M1.
struct SliceRoot: View {
    private let levels: [Level] = ContentStore.loadPacks().flatMap(\.levels)
    @State private var index = 0

    var body: some View {
        if levels.isEmpty {
            Text("لا توجد ألغاز").font(Theme.F.title).foregroundStyle(Theme.C.textMuted)
        } else {
            BoardScreen(level: levels[index], onNext: index + 1 < levels.count ? { index += 1 } : nil)
                .id(levels[index].id)
        }
    }
}
