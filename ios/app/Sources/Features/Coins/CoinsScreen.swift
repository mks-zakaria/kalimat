import SwiftUI

/// S07 — coins: balance and the real ways to earn them today.
/// (Coin packs and the rewarded ad are added here in M2, when they are live.)
struct CoinsSheet: View {
    @Environment(ProgressStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var ads = AdService.shared
    @State private var justEarned = false

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

            if ads.canRequestAds {
                Button {
                    ads.showRewarded {
                        Task { @MainActor in
                            store.earn(AdService.rewardCoins)
                            SoundService.shared.play(.coin)
                            justEarned = true
                        }
                    }
                } label: {
                    GameButton(title: ads.rewardedReady ? "شاهد إعلانًا واربح \(arNum(AdService.rewardCoins))" : "جارٍ تجهيز الإعلان…",
                               icon: "play.rectangle.fill", style: .primary, height: 52)
                }
                .buttonStyle(PressStyle())
                .disabled(!ads.rewardedReady)
                .opacity(ads.rewardedReady ? 1 : 0.6)
                .accessibilityIdentifier("coins.watch")
            }
            if justEarned {
                Text("أضفنا \(arNum(AdService.rewardCoins)) عملة إلى رصيدك").font(Theme.F.caption).foregroundStyle(Theme.C.success)
            }

            Spacer(minLength: 0)
            Button { dismiss() } label: { GameButton(title: "حسنًا", style: .gold, height: 52) }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("coins.close")
            if ads.privacyOptionsRequired {
                Button("إعدادات الخصوصية والإعلانات") { ads.showPrivacyOptions() }
                    .font(Theme.F.caption).foregroundStyle(Theme.C.panelMuted)
                    .accessibilityIdentifier("coins.privacy")
            }
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

// MARK: - Out of coins

extension View {
    /// The game-styled "not enough coins" card (replaces the system alert, whose buttons took
    /// the app's red tint). Fades in over the screen, no sheet slide.
    func noCoinsCard(isPresented: Binding<Bool>) -> some View {
        fullScreenCover(isPresented: isPresented) {
            NoCoinsCard(isPresented: isPresented).presentationBackground(.clear)
        }
        .transaction { if isPresented.wrappedValue { $0.disablesAnimations = true } }
    }
}

struct NoCoinsCard: View {
    @Binding var isPresented: Bool
    @Environment(ProgressStore.self) private var store
    @State private var ads = AdService.shared
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.55 : 0).ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityHidden(true)

            VStack(spacing: Theme.S.md) {
                CoinIcon(size: 64)
                Text("رصيدك من العملات لا يكفي")
                    .font(Theme.F.title).foregroundStyle(Theme.C.panelText)
                Text("أنهِ الألغاز لتربح عملات: ٥ لكل لغز و١٠ إذا حصلت على ٣ نجوم.")
                    .font(Theme.F.body).foregroundStyle(Theme.C.panelMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if ads.canRequestAds {
                    Button {
                        var t = Transaction(); t.disablesAnimations = true
                        withTransaction(t) { isPresented = false }
                        // let the card go away first: an ad can't present over a closing cover
                        Task { @MainActor [ads, store] in
                            try? await Task.sleep(for: .milliseconds(400))
                            ads.showRewarded {
                                Task { @MainActor in
                                    store.earn(AdService.rewardCoins)
                                    SoundService.shared.play(.coin)
                                }
                            }
                        }
                    } label: {
                        GameButton(title: ads.rewardedReady ? "شاهد إعلانًا واربح \(arNum(AdService.rewardCoins))" : "جارٍ تجهيز الإعلان…",
                                   icon: "play.rectangle.fill", style: .gold, height: 54)
                    }
                    .buttonStyle(PressStyle())
                    .disabled(!ads.rewardedReady)
                    .opacity(ads.rewardedReady ? 1 : 0.6)
                    .accessibilityIdentifier("nocoins.watch")
                }

                Button { close() } label: { GameButton(title: "حسنًا", style: .light, height: 50) }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("nocoins.close")
            }
            .padding(Theme.S.xl)
            .background(Theme.C.panel, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.C.gold, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(Theme.S.xl)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("nocoins.card")
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appear = true } }
    }

    private func close() {
        SoundService.shared.play(.tap)
        withAnimation(.easeIn(duration: 0.18)) { appear = false }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { isPresented = false }
        }
    }
}
