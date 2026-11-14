import SwiftUI

// Primitives from replica/design/components.md. Pure SwiftUI (no UIKit) so the
// catalog can also be rendered on macOS for design review.

/// Numbers shown as Arabic-Indic digits (٠١٢…), as Gulf players read them.
func arNum(_ n: Int) -> String {
    n.formatted(.number.grouping(.never).locale(Locale(identifier: "ar_SA")))
}

// MARK: - Grid cell

enum CellState { case empty, active, hint, solved }

struct GridCell: View {
    var letter: String?
    var state: CellState = .empty
    var size: CGFloat = Theme.S.cellMax

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.R.cell)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.R.cell)
                    .stroke(Theme.C.border, lineWidth: state == .empty ? 1 : 0)
            )
            .overlay(
                Text(letter ?? "")
                    .font(Theme.arabic(size * 0.55, .bold))
                    .foregroundStyle(state == .solved ? Theme.C.onCellSolved : Theme.C.cellText)
                    .minimumScaleFactor(0.5)
            )
            .frame(width: size, height: size)
    }

    private var fill: Color {
        switch state {
        case .empty: Theme.C.cell
        case .active: Theme.C.cellActive
        case .hint: Theme.C.cellHint
        case .solved: Theme.C.cellSolved
        }
    }
}

/// A board from a sparse map of cells. `col` 0 is the rightmost column; the
/// view relies on the RTL layout direction to place it there.
struct CrosswordBoard: View {
    struct Cell: Hashable { let row: Int; let col: Int }
    var rows: Int
    var cols: Int
    var letters: [Cell: String]
    var states: [Cell: CellState]
    var cellSize: CGFloat = 34
    var onTap: ((Cell) -> Void)? = nil

    var body: some View {
        Grid(horizontalSpacing: Theme.S.cellGap, verticalSpacing: Theme.S.cellGap) {
            ForEach(0..<rows, id: \.self) { r in
                GridRow {
                    ForEach(0..<cols, id: \.self) { c in
                        let key = Cell(row: r, col: c)
                        if let state = states[key] {
                            GridCell(letter: letters[key], state: state, size: cellSize)
                                .contentShape(Rectangle())
                                .onTapGesture { onTap?(key) }
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Clue card

struct ClueCard: View {
    var category: String
    var clue: String
    var imageSystemName: String? = nil   // real picture clues use bundled assets

    var body: some View {
        VStack(spacing: Theme.S.md) {
            Text(category)
                .font(Theme.F.caption)
                .foregroundStyle(Theme.C.textMuted)
            if let imageSystemName {
                Image(systemName: imageSystemName)
                    .resizable().scaledToFit()
                    .foregroundStyle(Theme.C.accent)
                    .frame(height: 90)
            }
            Text(clue)
                .font(Theme.F.clue)
                .foregroundStyle(Theme.C.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.S.xl)
        .frame(maxWidth: .infinity)
        .background(Theme.C.surface, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .overlay(alignment: .topLeading) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.C.accent)
                .padding(Theme.S.md)
        }
        .cardShadow()
    }
}

// MARK: - Answer slots

enum SlotState { case empty, typed, revealed, wrong, solved }

struct AnswerSlots: View {
    var letters: [String?]
    var states: [SlotState]

    var body: some View {
        let size: CGFloat = letters.count > 7 ? 36 : Theme.S.slot
        HStack(spacing: 6) {
            ForEach(letters.indices, id: \.self) { i in
                let st = states[i]
                RoundedRectangle(cornerRadius: Theme.R.cell)
                    .fill(fill(st))
                    .overlay(RoundedRectangle(cornerRadius: Theme.R.cell)
                        .stroke(stroke(st), lineWidth: st == .wrong ? 2 : 1.5))
                    .overlay(Text(letters[i] ?? "")
                        .font(Theme.arabic(size * 0.55, .bold))
                        .foregroundStyle(st == .solved ? Theme.C.onCellSolved : Theme.C.cellText))
                    .frame(width: size, height: size)
            }
        }
    }

    private func fill(_ s: SlotState) -> Color {
        switch s {
        case .revealed: Theme.C.cellHint
        case .solved: Theme.C.cellSolved
        default: Theme.C.surface
        }
    }
    private func stroke(_ s: SlotState) -> Color {
        switch s {
        case .wrong: Theme.C.danger
        case .empty, .typed: Theme.C.borderInput
        default: .clear
        }
    }
}

// MARK: - Letter bank

enum KeyState { case normal, used, removed }

struct LetterKey: View {
    var letter: String
    var state: KeyState = .normal

    var body: some View {
        Text(letter)
            .font(Theme.F.key)
            .foregroundStyle(state == .used ? Theme.C.keyUsedText : Theme.C.keyText)
            .frame(width: Theme.S.key, height: Theme.S.key)
            .background(state == .used ? Theme.C.keyUsed : Theme.C.key,
                        in: RoundedRectangle(cornerRadius: Theme.R.key))
            .shadow(color: Color(hex: 0x1E2230).opacity(state == .normal ? 0.18 : 0), radius: 0, y: 1)
            .opacity(state == .removed ? 0 : 1)
            .accessibilityHidden(state == .removed)
    }
}

struct LetterBank: View {
    var keys: [(String, KeyState)]
    var body: some View {
        let half = (keys.count + 1) / 2
        VStack(spacing: Theme.S.sm) {
            HStack(spacing: 6) { ForEach(0..<half, id: \.self) { LetterKey(letter: keys[$0].0, state: keys[$0].1) } }
            HStack(spacing: 6) { ForEach(half..<keys.count, id: \.self) { LetterKey(letter: keys[$0].0, state: keys[$0].1) } }
        }
    }
}

// MARK: - Hints, coins, stars

struct CoinChip: View {
    var amount: Int
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill").font(.system(size: 10)).foregroundStyle(Theme.C.warning)
            Text(arNum(amount)).font(Theme.F.number).foregroundStyle(Theme.C.onCoin)
        }
        .padding(.horizontal, Theme.S.sm).padding(.vertical, 3)
        .background(Theme.C.coin, in: Capsule())
    }
}

struct HintButton: View {
    enum Kind { case reveal, remove }
    var kind: Kind
    var cost: Int
    var enabled = true

    var body: some View {
        HStack(spacing: Theme.S.sm) {
            Image(systemName: kind == .reveal ? "eye" : "eraser")
            Text(kind == .reveal ? "كشف حرف" : "حذف حرف")
                .font(Theme.arabic(16, .semibold))
                .lineLimit(1).fixedSize()
            CoinChip(amount: cost)
        }
        .foregroundStyle(Theme.C.accent)
        .padding(.horizontal, Theme.S.md).frame(height: 44)
        .background(Theme.C.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.C.border))
        .opacity(enabled ? 1 : 0.4)
    }
}

struct CoinBadge: View {
    var coins: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill").foregroundStyle(Theme.C.accent)
            Text(arNum(coins)).font(Theme.F.number).foregroundStyle(Theme.C.onCoin)
            Image(systemName: "circle.fill").font(.system(size: 12)).foregroundStyle(Theme.C.warning)
        }
        .padding(.horizontal, Theme.S.md).frame(height: 34)
        .background(Theme.C.coin, in: Capsule())
    }
}

struct StarsView: View {
    var stars: Int
    var size: CGFloat = 14
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < stars ? Theme.C.warning : Theme.C.borderInput)
            }
        }
    }
}

// MARK: - Navigation & lists

struct TopBar<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Image(systemName: "chevron.forward")   // points "back" in RTL
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.C.accent)
                .frame(width: 44, height: 44)
            Spacer()
            Text(title).font(Theme.F.title).foregroundStyle(Theme.C.text)
            Spacer()
            trailing
        }
        .padding(.horizontal, Theme.S.sm)
        .frame(height: Theme.S.topbar)
    }
}

enum TileState { case locked, open, solved(Int) }

struct LevelTile: View {
    var number: Int
    var state: TileState

    var body: some View {
        VStack(spacing: 4) {
            if case .locked = state {
                Image(systemName: "lock.fill").foregroundStyle(Theme.C.textMuted)
            } else {
                Text(arNum(number)).font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isSolved ? Theme.C.onCellSolved : Theme.C.accent)
            }
            if case .solved(let s) = state { StarsView(stars: s, size: 10) }
        }
        .frame(width: 72, height: 72)
        .background(isSolved ? Theme.C.cellSolved : Theme.C.surface, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.R.card)
            .stroke(isOpen ? Theme.C.accent : Theme.C.border, lineWidth: isOpen ? 2 : 1))
    }
    private var isSolved: Bool { if case .solved = state { true } else { false } }
    private var isOpen: Bool { if case .open = state { true } else { false } }
}

struct PackCard: View {
    var title: String
    var solved: Int
    var total: Int
    var locked = false

    var body: some View {
        HStack(spacing: Theme.S.md) {
            VStack(alignment: .leading, spacing: Theme.S.sm) {
                Text(title).font(Theme.F.title).foregroundStyle(Theme.C.text)
                if locked {
                    Text("افتحها بجمع ٣٠ نجمة").font(Theme.F.caption).foregroundStyle(Theme.C.textMuted)
                } else {
                    ProgressBar(fraction: total == 0 ? 0 : Double(solved) / Double(total))
                    Text("\(arNum(solved)) / \(arNum(total))").font(Theme.F.number).foregroundStyle(Theme.C.textMuted)
                }
            }
            Spacer()
            Image(systemName: locked ? "lock.fill" : "chevron.backward")
                .foregroundStyle(locked ? Theme.C.textMuted : Theme.C.accent)
        }
        .padding(Theme.S.lg)
        .background(Theme.C.surface, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .cardShadow()
    }
}

/// Own bar instead of ProgressView: same look on every OS, fills from the right in RTL.
struct ProgressBar: View {
    var fraction: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.C.border)
                Capsule().fill(Theme.C.success).frame(width: g.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(fraction * 100))٪"))
    }
}

struct PrimaryButton: View {
    var title: String
    var secondary = false
    var body: some View {
        Text(title)
            .font(Theme.arabic(18, .bold))
            .foregroundStyle(secondary ? Theme.C.accent : Theme.C.onAccent)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(secondary ? Theme.C.surface : Theme.C.accent, in: Capsule())
            .overlay(Capsule().stroke(secondary ? Theme.C.accent : .clear, lineWidth: 1.5))
    }
}
