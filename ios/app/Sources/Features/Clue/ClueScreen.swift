import SwiftUI

/// S05 — one clue: the card, the answer slots and the letter bank.
struct ClueScreen: View {
    @Bindable var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var shake = 0

    var body: some View {
        if let entry = engine.current {
            VStack(spacing: Theme.S.xl) {
                ClueCard(category: categoryName(entry.category), clue: entry.clueAr)
                    .padding(.top, Theme.S.xl)

                AnswerSlots(letters: engine.typed, states: slotStates)
                    .modifier(Shake(amount: CGFloat(shake)))
                    .overlay {
                        // invisible buttons over each slot: tap a typed letter to send it back
                        HStack(spacing: 6) {
                            ForEach(engine.typed.indices, id: \.self) { i in
                                Color.clear.contentShape(Rectangle())
                                    .frame(width: engine.typed.count > 7 ? 36 : Theme.S.slot,
                                           height: engine.typed.count > 7 ? 36 : Theme.S.slot)
                                    .onTapGesture { engine.tapSlot(i) }
                                    .accessibilityLabel("حرف \(arNum(i + 1))")
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)

                Spacer(minLength: 0)

                bank
            }
            .padding(Theme.S.lg)
            .background(Theme.C.bg.ignoresSafeArea())
            .onChange(of: engine.lastWrong) { _, wrong in
                if wrong { withAnimation(.default) { shake += 1 } }
            }
            .onChange(of: engine.currentSolved) { _, done in
                if done { Task { try? await Task.sleep(for: .milliseconds(600)); dismiss() } }
            }
        }
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
                Button { engine.tapKey(k) } label: {
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
            if engine.isLocked(i) { return .revealed }
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
