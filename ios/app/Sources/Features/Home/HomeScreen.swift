import SwiftUI

/// S01 — title, continue, all packs.
struct HomeScreen: View {
    let packs: [Pack]
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store

    var body: some View {
        VStack(spacing: Theme.S.xl) {
            HStack { Spacer(); CoinBadge(coins: store.coins) }
            Spacer()
            VStack(spacing: Theme.S.sm) {
                Text("كلمات").font(Theme.F.display).foregroundStyle(Theme.C.accent)
                Text("كلمات متقاطعة بنكهة خليجية").font(Theme.F.body).foregroundStyle(Theme.C.textMuted)
            }
            Spacer()
            if let (level, pack) = nextLevel(in: packs, store: store) {
                Button { path.append(.board(level, pack)) } label: {
                    PrimaryButton(title: store.file.levels.isEmpty ? "ابدأ اللعب" : "تابع: لغز \(arNum(level.number))")
                }
            } else if !packs.isEmpty {
                Text("أنهيت كل الألغاز! انتظر مجموعات جديدة قريبًا")
                    .font(Theme.F.body).foregroundStyle(Theme.C.success).multilineTextAlignment(.center)
            }
            Button { path.append(.packs) } label: { PrimaryButton(title: "المجموعات", secondary: true) }
                .disabled(packs.isEmpty)
        }
        .padding(Theme.S.xl)
        .background(Theme.C.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
