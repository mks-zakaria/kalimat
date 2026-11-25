import SwiftUI

/// Runs the solve clock for one level while it is on screen, unfinished and the app is in
/// the foreground. Every pause adds the active seconds to the level's saved time.
struct SolveTiming: ViewModifier {
    let levelId: String
    let running: Bool
    @Environment(\.scenePhase) private var phase
    @Environment(ProgressStore.self) private var store
    @State private var clock = SolveClock()

    func body(content: Content) -> some View {
        content
            .onAppear {
                clock.onPause = { [store, levelId] in store.addTime(levelId, $0) }
                if running && phase == .active { clock.resume() }
            }
            .onDisappear { clock.pause() }
            .onChange(of: phase) { _, p in
                if p == .active && running { clock.resume() } else { clock.pause() }
            }
            .onChange(of: running) { _, r in
                if r && phase == .active { clock.resume() } else { clock.pause() }
            }
    }
}

extension View {
    func solveTiming(levelId: String, running: Bool) -> some View {
        modifier(SolveTiming(levelId: levelId, running: running))
    }
}

// MARK: - Animated number

/// Counts an IQ value from `from` to `to`, digit by digit, then reports the change.
struct IQCounter: View {
    let from: Int
    let to: Int
    var font: Font = .system(size: 30, weight: .heavy, design: .rounded)
    var delay: Duration = .zero
    var onDone: (() -> Void)? = nil
    @State private var shown: Int?

    var body: some View {
        Text(arNum(shown ?? from))
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(shown ?? from)))
            .task(id: to) {
                shown = from
                guard from != to else { onDone?(); return }
                try? await Task.sleep(for: delay)
                let steps = abs(to - from), dir = to > from ? 1 : -1
                let pause = max(25, min(90, 1100 / max(steps, 1)))           // whole count ≈ 1 s
                for i in 1...steps {
                    withAnimation(.snappy(duration: 0.12)) { shown = from + dir * i }
                    try? await Task.sleep(for: .milliseconds(pause))
                }
                onDone?()
            }
    }
}

/// Up / down arrow with the size of the change, bouncing in once the count has finished.
struct IQDeltaBadge: View {
    let delta: Int
    @State private var bounce = 0

    var body: some View {
        let up = delta > 0
        HStack(spacing: 3) {
            Image(systemName: up ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .symbolEffect(.bounce.byLayer, value: bounce)
            Text((up ? "+" : "−") + arNum(abs(delta)))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(up ? Theme.C.success : Theme.C.danger, in: Capsule())
        .onAppear { bounce += 1 }
        .accessibilityLabel(up ? "ارتفع \(arNum(delta))" : "انخفض \(arNum(-delta))")
    }
}

// MARK: - Level complete

/// The IQ box on the level-complete card: this level's score, then the overall IQ counting
/// from its old value to the new one with an arrow. Tap it for the explanation card.
struct IQResultView: View {
    let result: IQResult
    @State private var counted = false
    @State private var glow = false
    @State private var showCard = false

    private var delta: Int { result.counted ? result.after - (result.before ?? result.after) : 0 }

    var body: some View {
        Button {
            SoundService.shared.play(.tap)
            showCard = true
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile").foregroundStyle(Theme.C.turquoise)
                    Text("ذكاؤك في هذا اللغز: \(arNum(result.level))")
                        .font(Theme.arabic(16, .bold)).foregroundStyle(Theme.C.panelText)
                    Image(systemName: "info.circle").font(.system(size: 13)).foregroundStyle(Theme.C.panelMuted)
                }
                HStack(spacing: 8) {
                    Text(!result.counted ? "معدّلك (إعادة لا تُحتسب)" : result.before == nil ? "أول معدّل لذكائك" : "معدّل ذكائك")
                        .font(Theme.F.caption).foregroundStyle(Theme.C.panelMuted)
                    IQCounter(from: result.before ?? result.after, to: result.after,
                              font: .system(size: 28, weight: .heavy, design: .rounded), delay: .milliseconds(1500)) {
                        counted = true
                        if delta != 0 {
                            SoundService.shared.play(delta > 0 ? .star : .undo)
                            withAnimation(.easeOut(duration: 0.25)) { glow = true }
                            Task { try? await Task.sleep(for: .milliseconds(900)); withAnimation(.easeIn(duration: 0.6)) { glow = false } }
                        }
                    }
                    .foregroundStyle(Theme.C.panelText)
                    if counted && delta != 0 {
                        IQDeltaBadge(delta: delta).transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: counted)
            }
            .padding(.horizontal, Theme.S.lg).padding(.vertical, Theme.S.sm)
            .background(Theme.C.turquoise.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.R.key))
            .overlay(RoundedRectangle(cornerRadius: Theme.R.key)
                .stroke(delta > 0 ? Theme.C.success : Theme.C.danger, lineWidth: 2).opacity(glow ? 1 : 0))
            .shadow(color: (delta > 0 ? Theme.C.success : Theme.C.danger).opacity(glow ? 0.6 : 0), radius: glow ? 12 : 0)
            .scaleEffect(glow ? 1.05 : 1)
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("iq.level")
        .iqCard(isPresented: $showCard)
    }
}

// MARK: - Home

/// Home: the player's IQ. When it changed since it was last on screen, it counts to the new
/// value with a green or red pulse. Tap it for the explanation card.
struct IQButton: View {
    @Environment(ProgressStore.self) private var store
    @State private var showCard = false
    @State private var from: Int?
    @State private var delta = 0
    @State private var pulse = false
    /// Last value the home button showed in this run of the app.
    @MainActor private static var lastShown: Int?

    var body: some View {
        Button {
            SoundService.shared.play(.tap)
            showCard = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                if let iq = store.iq {
                    Text("معدّل ذكائك").font(Theme.arabic(16, .bold))
                    IQCounter(from: from ?? iq, to: iq, font: .system(size: 18, weight: .heavy, design: .rounded),
                              delay: .milliseconds(450)) { finished(iq) }
                } else {
                    Text("اكتشف معدّل ذكائك").font(Theme.arabic(16, .bold))
                }
                if delta != 0 {
                    Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(delta > 0 ? Color(hex: 0xB9F6CA) : Color(hex: 0xFFCDD2))
                        .transition(.move(edge: delta > 0 ? .bottom : .top).combined(with: .opacity))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.S.lg).padding(.vertical, 6)
            .background((pulse ? (delta >= 0 ? Theme.C.success : Theme.C.danger) : Theme.C.turquoise).opacity(0.9), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            .shadow(color: pulse ? .white.opacity(0.5) : .clear, radius: pulse ? 10 : 0)
            .scaleEffect(pulse ? 1.12 : 1)
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.iq")
        .onAppear {
            // count from what the button showed last time, so a change is visible
            from = Self.lastShown ?? store.iq
        }
        .iqCard(isPresented: $showCard)
    }

    private func finished(_ iq: Int) {
        let d = iq - (from ?? iq)
        Self.lastShown = iq
        guard d != 0 else { return }
        SoundService.shared.play(d > 0 ? .star : .undo)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { delta = d; pulse = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeOut(duration: 0.5)) { pulse = false; delta = 0 }
            from = iq
        }
    }
}

// MARK: - Explanation card

extension View {
    /// Shows the IQ explanation card over everything, without the sheet slide.
    func iqCard(isPresented: Binding<Bool>) -> some View {
        fullScreenCover(isPresented: isPresented) {
            IQCard(isPresented: isPresented)
                .presentationBackground(.clear)
        }
        .transaction { if isPresented.wrappedValue { $0.disablesAnimations = true } }
    }
}

/// What the IQ score is, how it is calculated, and the player's numbers.
struct IQCard: View {
    @Binding var isPresented: Bool
    @Environment(ProgressStore.self) private var store
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.55 : 0).ignoresSafeArea()
                .onTapGesture(perform: close)
                .accessibilityHidden(true)

            VStack(spacing: Theme.S.md) {
                ZStack {
                    Circle().fill(Theme.C.turquoise.opacity(0.15)).frame(width: 84, height: 84)
                    Image(systemName: "brain.head.profile").font(.system(size: 42)).foregroundStyle(Theme.C.turquoise)
                        .symbolEffect(.pulse, options: .repeat(2), value: appear)
                }
                Text("ما هو معدّل الذكاء؟").font(Theme.F.title).foregroundStyle(Theme.C.panelText)

                HStack(spacing: Theme.S.sm) {
                    stat(store.iq.map(arNum) ?? "—", "معدّلك", id: "iq.value")
                    stat(store.bestLevelIQ.map(arNum) ?? "—", "أفضل لغز")
                    stat(store.lastLevelIQ.map(arNum) ?? "—", "آخر لغز")
                }

                VStack(alignment: .leading, spacing: Theme.S.sm) {
                    row("timer", "نقيس وقت حلّك الفعلي لكل لغز جديد، دون وقت الإعلانات أو خروجك من اللعبة.")
                    row("gauge.with.needle", "نقارنه بالوقت المتوقع حسب عدد الكلمات وطولها وصعوبتها: في الوقت = ١٠٠، أسرع بمرتين = ١٢٠، أبطأ بمرتين = ٨٠.")
                    row("lightbulb", "كل مساعدة تنقص ٥ نقاط من نتيجة اللغز.")
                    row("arrow.triangle.2.circlepath", "بعد كل لغز يتحدّث معدّلك بين نتيجتك فيه ومعدّلك السابق، فيرتفع إذا كنت أسرع ويهبط إذا كنت أبطأ. إعادة اللعب لا تُحتسب.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(store.iq == nil ? "أنهِ لغزك الأول لتعرف معدّلك."
                                     : "مبني على \(puzzles(store.file.iqLevels)).")
                    .font(Theme.F.caption).foregroundStyle(Theme.C.panelMuted)
                Text("تقدير للمتعة مبني على سرعتك في الحل، وليس اختبار ذكاء علميًا.")
                    .font(Theme.F.caption).foregroundStyle(Theme.C.panelMuted)
                    .multilineTextAlignment(.center)

                Button(action: close) { GameButton(title: "حسنًا", style: .gold, height: 50) }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("iq.close")
            }
            .padding(Theme.S.xl)
            .background(Theme.C.panel, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.C.turquoise, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(Theme.S.lg)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("iq.card")
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

    private func stat(_ value: String, _ label: String, id: String? = nil) -> some View {
        VStack(spacing: 0) {
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(Theme.C.panelText)
                .accessibilityIdentifier(id ?? "")
            Text(label).font(Theme.F.caption).foregroundStyle(Theme.C.panelMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Theme.S.sm)
        .background(Theme.C.tile, in: RoundedRectangle(cornerRadius: Theme.R.key))
        .overlay(RoundedRectangle(cornerRadius: Theme.R.key).stroke(Theme.C.tileEdge.opacity(0.35), lineWidth: 1))
    }

    /// "على لغز واحد / لغزين / ٣ ألغاز / ١١ لغزًا"
    private func puzzles(_ n: Int) -> String {
        n == 1 ? "لغز واحد" : n == 2 ? "لغزين" : (3...10).contains(n % 100) ? "\(arNum(n)) ألغاز" : "\(arNum(n)) لغزًا"
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.S.md) {
            Image(systemName: icon).foregroundStyle(Theme.C.goldShade).frame(width: 22)
            Text(text).font(Theme.arabic(14)).foregroundStyle(Theme.C.panelText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
