import SwiftUI

/// S07 — coins: balance and the real ways to earn them today.
/// (Coin packs and the rewarded ad are added here in M2, when they are live.)
struct CoinsSheet: View {
    @Environment(ProgressStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.S.lg) {
            Capsule().fill(Theme.C.tileEdge.opacity(0.4)).frame(width: 40, height: 5).padding(.top, Theme.S.sm)

            CoinIcon(size: 64)
            Text(arNum(store.coins))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.C.panelText)
                .accessibilityIdentifier("coins.balance")
            Text("رصيدك من العملات").font(Theme.F.body).foregroundStyle(Theme.C.panelMuted)

            Panel {
                VStack(alignment: .leading, spacing: Theme.S.md) {
                    Text("كيف تربح العملات؟").font(Theme.F.title).foregroundStyle(Theme.C.panelText)
                    earnRow(icon: "checkmark.seal.fill", text: "أنهِ لغزًا جديدًا", amount: 5)
                    earnRow(icon: "star.fill", text: "أنهِه بثلاث نجوم بدون مساعدة", amount: 10)
                    Divider()
                    Text("استخدم العملات لكشف حرف (\(arNum(ProgressStore.revealCost))) أو حذف حرف خاطئ (\(arNum(ProgressStore.removeCost))).")
                        .font(Theme.F.caption).foregroundStyle(Theme.C.panelMuted)
                }
                .padding(Theme.S.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
            Button { dismiss() } label: { GameButton(title: "حسنًا", style: .gold, height: 52) }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("coins.close")
        }
        .padding(Theme.S.xl)
        .background(Theme.C.panel.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.medium, .large])
    }

    private func earnRow(icon: String, text: String, amount: Int) -> some View {
        HStack(spacing: Theme.S.md) {
            Image(systemName: icon).foregroundStyle(Theme.C.goldShade).frame(width: 24)
            Text(text).font(Theme.F.body).foregroundStyle(Theme.C.panelText)
            Spacer()
            CoinChip(amount: amount)
        }
    }
}

/// The coin counter as a real button (it used to look tappable and do nothing).
struct CoinButton: View {
    @Environment(ProgressStore.self) private var store
    @State private var open = false

    var body: some View {
        Button {
            SoundService.shared.play(.coin)
            open = true
        } label: {
            CoinBadge(coins: store.coins)
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("coins.button")
        .accessibilityLabel("العملات \(arNum(store.coins))")
        .sheet(isPresented: $open) { CoinsSheet().environment(store) }
    }
}

/// Short message that slides in from the top and hides itself.
struct Toast: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(message)
                    .font(Theme.arabic(16, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.S.lg).padding(.vertical, Theme.S.sm)
                    .background(Theme.C.coinPill.opacity(0.9), in: Capsule())
                    .overlay(Capsule().stroke(Theme.C.gold, lineWidth: 1.5))
                    .padding(.top, 64)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("toast")
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { self.message = nil }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View { modifier(Toast(message: message)) }
}
