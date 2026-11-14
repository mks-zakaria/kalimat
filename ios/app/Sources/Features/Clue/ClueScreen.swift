import SwiftUI

/// S05 — one clue: the card, the answer slots and the letter bank.
struct ClueScreen: View {
    @Bindable var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var store
    @State private var shake = 0
    @State private var noCoins = false

    var body: some View {
        if let entry = engine.current {
            VStack(spacing: Theme.S.xl) {
                HStack { Spacer(); CoinBadge(coins: store.coins) }
                    .padding(.top, Theme.S.lg)

                ClueCard(category: categoryName(entry.category), clue: entry.clueAr)

                AnswerSlots(letters: engine.typed, states: slotStates)
                    .modifier(Shake(amount: CGFloat(shake)))
                    .overlay {
                        // invisible buttons over each slot: tap a typed letter to send it back
                        HStack(spacing: 6) {
                            ForEach(engine.typed.indices, id: \.self) { i in
                                Color.clear.contentShape(Rectangle())
                                    .frame(width: engine.typed.count > 7 ? 36 : Theme.S.slot,
                                           height: engine.typed.count > 7 ? 36 : Theme.S.slot)
                                    .onTapGesture {
                                        if engine.typed[i] != nil && !engine.isLocked(i) { SoundService.shared.play(.undo) }
                                        engine.tapSlot(i)
                                    }
                                    .accessibilityLabel("حرف \(arNum(i + 1))")
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)

                Spacer(minLength: 0)

                HStack(spacing: Theme.S.sm) {
                    Button { useHint(ProgressStore.revealCost, sound: .hint) { engine.revealLetter() } } label: {
                        HintButton(kind: .reveal, cost: ProgressStore.revealCost, enabled: engine.canReveal)
                    }
                    .disabled(!engine.canReveal)
                    Button { useHint(ProgressStore.removeCost, sound: .erase) { engine.removeDecoy() } } label: {
                        HintButton(kind: .remove, cost: ProgressStore.removeCost, enabled: engine.canRemoveDecoy)
                    }
                    .disabled(!engine.canRemoveDecoy)
                }
                .buttonStyle(.plain)

                bank
            }
            .padding(Theme.S.lg)
            .background(Theme.C.bg.ignoresSafeArea())
            .alert("رصيدك من العملات لا يكفي", isPresented: $noCoins) {
                Button("حسنًا", role: .cancel) {}
            } message: {
                Text("حل ألغازًا أخرى بدون مساعدة لتجمع المزيد.")
            }
            .onChange(of: engine.lastWrong) { _, wrong in
                if wrong {
                    SoundService.shared.play(.wrong)
                    withAnimation(.default) { shake += 1 }
                }
            }
            .onChange(of: engine.currentSolved) { _, done in
                if done {
                    SoundService.shared.play(.correct)
                    Task { try? await Task.sleep(for: .milliseconds(600)); dismiss() }
                }
            }
        }
    }

    private func useHint(_ cost: Int, sound: SoundService.Sound, _ action: () -> Void) {
        guard store.spend(cost) else {
            SoundService.shared.play(.wrong)
            noCoins = true
            return
        }
        SoundService.shared.play(.coin)
        SoundService.shared.play(sound)
        action()
    }

    private var bank: some View {
        let keys = engine.bank
        let half = (keys.count + 1) / 2
        return VStack(spacing: Theme.S.sm) {
            row(keys[0..<half])
            row(keys[half..<keys.count])
        }
    }

    private func row(_ keys: ArraySlice<BankKey>) -> some View {
        HStack(spacing: 6) {
            ForEach(keys) { k in
                Button {
                    SoundService.shared.play(.key)
                    engine.tapKey(k)
                } label: {
                    LetterKey(letter: k.letter, state: k.removed ? .removed : (k.used ? .used : .normal))
                }
                .buttonStyle(.plain)
                .disabled(k.used || k.removed || engine.currentSolved)
                .accessibilityLabel(k.letter)
            }
        }
    }

    private var slotStates: [SlotState] {
        engine.typed.indices.map { i in
            if engine.currentSolved { return .solved }
            if engine.isRevealed(i) { return .revealed }
            if engine.isLocked(i) { return .solved }
            if engine.lastWrong { return .wrong }
            return engine.typed[i] == nil ? .empty : .typed
        }
    }

    private func categoryName(_ c: String) -> String {
        switch c {
        case "gulf": "الخليج"
        case "geography": "جغرافيا"
        case "religion": "ديني"
        case "sport": "رياضة"
        case "science": "علوم"
        case "language": "لغة"
        case "food": "مأكولات"
        case "history": "تاريخ"
        case "flags": "أعلام"
        default: "معلومات عامة"
        }
    }
}

/// Horizontal shake for a wrong answer.
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}
