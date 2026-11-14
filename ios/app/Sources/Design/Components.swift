import SwiftUI

// Primitives from replica/design/components.md (v2 game look). Pure SwiftUI.

/// Numbers shown as Arabic-Indic digits (٠١٢…), as Gulf players read them.
func arNum(_ n: Int) -> String {
    n.formatted(.number.grouping(.never).locale(Locale(identifier: "ar_SA")))
}

// MARK: - 3D tile (shared by grid cells, keys, slots, medallions, buttons)

/// A raised tile: a darker edge drawn below the face. `pressed` sinks it.
struct Tile3D<Content: View>: View {
    var face: [Color]
    var edge: Color
    var radius: CGFloat = Theme.R.key
    var depth: CGFloat = Theme.S.edge
    var pressed = false
    @ViewBuilder var content: Content

    var body: some View {
        let d = pressed ? 1 : depth
        ZStack {
            RoundedRectangle(cornerRadius: radius).fill(edge).offset(y: depth)
            RoundedRectangle(cornerRadius: radius)
                .fill(LinearGradient(colors: face, startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.55), lineWidth: 1).padding(1))
                .overlay(content)
                .offset(y: depth - d)
        }
        .padding(.bottom, depth)
    }
}

/// Pressed state for any button built from Tile3D.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Grid

enum CellState { case empty, active, hint, solved }

struct GridCell: View {
    var letter: String?
    var state: CellState = .empty
    var size: CGFloat = Theme.S.cellMax
    var isCursor = false

    var body: some View {
        Group {
            switch state {
            case .empty:
                RoundedRectangle(cornerRadius: Theme.R.cell)
                    .fill(.white.opacity(0.92))
                    .overlay(RoundedRectangle(cornerRadius: Theme.R.cell).stroke(Theme.C.tileEdge.opacity(0.5), lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
            case .active:
                RoundedRectangle(cornerRadius: Theme.R.cell)
                    .fill(Color(hex: 0xFFE9B8))
                    .overlay(RoundedRectangle(cornerRadius: Theme.R.cell)
                        .stroke(isCursor ? Theme.C.button : Theme.C.goldEdge, lineWidth: isCursor ? 3 : 2))
                    .shadow(color: Theme.C.gold.opacity(0.8), radius: 6)
            case .hint:
                Tile3D(face: [Color(hex: 0x24A096), Theme.C.turquoise], edge: Theme.C.turquoiseEdge,
                       radius: Theme.R.cell, depth: 3) { letterText(Theme.C.onTurquoise) }
            case .solved:
                Tile3D(face: [Theme.C.gold, Theme.C.goldShade], edge: Theme.C.goldEdge,
                       radius: Theme.R.cell, depth: 3) { letterText(Theme.C.onGold) }
            }
        }
        .overlay { if state == .empty || state == .active { letterText(Theme.C.tileText) } }
        .frame(width: size, height: size)
    }

    private func letterText(_ color: Color) -> some View {
        Text(letter ?? "")
            .font(Theme.arabic(size * 0.56, .bold))
            .foregroundStyle(color)
            .minimumScaleFactor(0.5)
            .offset(y: -size * 0.04)
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
    var cursor: Cell? = nil
    var onTap: ((Cell) -> Void)? = nil

    var body: some View {
        Grid(horizontalSpacing: Theme.S.cellGap, verticalSpacing: Theme.S.cellGap) {
            ForEach(0..<rows, id: \.self) { r in
                GridRow {
                    ForEach(0..<cols, id: \.self) { c in
                        let key = Cell(row: r, col: c)
                        if let state = states[key] {
                            GridCell(letter: letters[key], state: state, size: cellSize, isCursor: cursor == key)
                                .contentShape(Rectangle())
                                .onTapGesture { onTap?(key) }
                                .accessibilityElement()
                                .accessibilityLabel(letters[key] ?? "خانة فارغة")
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("cell.\(r).\(c)")
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Panels and clue

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(Theme.C.panel, in: RoundedRectangle(cornerRadius: Theme.R.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.R.card).stroke(Theme.C.gold.opacity(0.9), lineWidth: 1.5))
            .cardShadow()
    }
}

struct Category {
    let name: String
    let icon: String
    let color: Color

    static func of(_ id: String) -> Category {
        switch id {
        case "gulf": Category(name: "الخليج", icon: "sun.horizon.fill", color: Color(hex: 0xA5552A))
        case "geography": Category(name: "جغرافيا", icon: "globe.asia.australia.fill", color: Color(hex: 0x1F6E8C))
        case "religion": Category(name: "ديني", icon: "moon.stars.fill", color: Color(hex: 0x2E6B4F))
        case "sport": Category(name: "رياضة", icon: "soccerball", color: Color(hex: 0x3F51A0))
        case "science": Category(name: "علوم", icon: "atom", color: Color(hex: 0x6A3FA0))
        case "language": Category(name: "لغة", icon: "character.book.closed.fill", color: Color(hex: 0x8C2F39))
        case "food": Category(name: "مأكولات", icon: "cup.and.saucer.fill", color: Color(hex: 0x8A5A00))
        case "history": Category(name: "تاريخ", icon: "building.columns.fill", color: Color(hex: 0x5A4632))
        case "flags": Category(name: "أعلام", icon: "flag.fill", color: Color(hex: 0xB3261E))
        default: Category(name: "معلومات عامة", icon: "lightbulb.fill", color: Color(hex: 0x5A4632))
        }
    }
}

struct ClueCard: View {
    var category: String
    var clue: String
    var imageSystemName: String? = nil

    var body: some View {
        let cat = Category.of(category)
        Panel {
            VStack(spacing: Theme.S.sm) {
                Label(cat.name, systemImage: cat.icon)
                    .font(Theme.F.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.S.md).padding(.vertical, 4)
                    .background(cat.color, in: Capsule())
                if let imageSystemName {
                    Image(systemName: imageSystemName).resizable().scaledToFit()
                        .foregroundStyle(cat.color).frame(height: 80)
                }
                Text(clue)
                    .font(Theme.F.clue)
                    .foregroundStyle(Theme.C.panelText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3).minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Theme.S.md).padding(.horizontal, Theme.S.lg)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Answer slots

enum SlotState { case empty, typed, revealed, wrong, solved }

struct AnswerSlots: View {
    var letters: [String?]
    var states: [SlotState]
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        let size: CGFloat = letters.count > 7 ? 36 : Theme.S.slot
        HStack(spacing: 6) {
            ForEach(letters.indices, id: \.self) { i in
                slot(i, size)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(i) }
                    .accessibilityElement()
                    .accessibilityLabel(letters[i] ?? "فارغ")
                    // only a typed letter can be tapped (it goes back to the keys); empty or
                    // locked slots are not controls (dead-control audit, bug B04)
                    .accessibilityAddTraits(states[i] == .typed ? .isButton : [])
                    .accessibilityIdentifier("slot.\(i)")
            }
        }
    }

    @ViewBuilder private func slot(_ i: Int, _ size: CGFloat) -> some View {
        let st = states[i]
        let letter = Text(letters[i] ?? "").font(Theme.arabic(size * 0.56, .bold))
        switch st {
        case .solved:
            Tile3D(face: [Theme.C.gold, Theme.C.goldShade], edge: Theme.C.goldEdge, radius: Theme.R.cell, depth: 3) {
                letter.foregroundStyle(Theme.C.onGold)
            }.frame(width: size, height: size + 3)
        case .revealed:
            Tile3D(face: [Color(hex: 0x24A096), Theme.C.turquoise], edge: Theme.C.turquoiseEdge, radius: Theme.R.cell, depth: 3) {
                letter.foregroundStyle(Theme.C.onTurquoise)
            }.frame(width: size, height: size + 3)
        case .typed:
            Tile3D(face: [Theme.C.tile, Theme.C.tileShade], edge: Theme.C.tileEdge, radius: Theme.R.cell, depth: 3) {
                letter.foregroundStyle(Theme.C.tileText)
            }.frame(width: size, height: size + 3)
        case .empty, .wrong:
            RoundedRectangle(cornerRadius: Theme.R.cell)
                .fill(Theme.C.slot)
                .overlay(RoundedRectangle(cornerRadius: Theme.R.cell)
                    .stroke(st == .wrong ? Theme.C.danger : Theme.C.tileEdge.opacity(0.6), lineWidth: st == .wrong ? 2.5 : 1))
                .frame(width: size, height: size)
                .padding(.bottom, 3)
        }
    }
}

// MARK: - Letter bank

enum KeyState { case normal, used, removed }

struct LetterKey: View {
    var letter: String
    var state: KeyState = .normal
    var size: CGFloat = Theme.S.key

    var body: some View {
        Group {
            if state == .used {
                RoundedRectangle(cornerRadius: Theme.R.key)
                    .fill(Theme.C.slot.opacity(0.6))
                    .overlay(Text(letter).font(Theme.arabic(size * 0.56, .bold)).foregroundStyle(Theme.C.panelMuted.opacity(0.6)))
                    .padding(.top, Theme.S.edge)
            } else {
                Tile3D(face: [Theme.C.tile, Theme.C.tileShade], edge: Theme.C.tileEdge) {
                    Text(letter).font(Theme.arabic(size * 0.56, .bold)).foregroundStyle(Theme.C.tileText)
                        .offset(y: -2)
                }
            }
        }
        .frame(width: size, height: size + Theme.S.edge)
        .opacity(state == .removed ? 0 : 1)
        .scaleEffect(state == .removed ? 0.4 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state)
        .accessibilityHidden(state == .removed)
    }
}

// MARK: - Coins, stars, hints

/// Drawn gold coin (no image assets).
struct CoinIcon: View {
    var size: CGFloat = 20
    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [Color(hex: 0xFFE08A), Theme.C.goldShade], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().stroke(Theme.C.goldEdge, lineWidth: size * 0.1))
            .overlay(Circle().stroke(Color(hex: 0xFFF1C2), lineWidth: 1).padding(size * 0.22))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }
}

struct CoinChip: View {
    var amount: Int
    var body: some View {
        HStack(spacing: 4) {
            CoinIcon(size: 14)
            Text(arNum(amount)).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.C.onGold)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Theme.C.gold.opacity(0.35), in: Capsule())
    }
}

struct CoinBadge: View {
    var coins: Int
    var body: some View {
        HStack(spacing: 6) {
            CoinIcon(size: 22)
            Text(arNum(coins)).font(Theme.F.number).foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring, value: coins)
        }
        .padding(.leading, 6).padding(.trailing, 12).frame(height: 36)
        .background(Theme.C.coinPill.opacity(0.75), in: Capsule())
        .overlay(Capsule().stroke(Theme.C.gold.opacity(0.8), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("العملات \(arNum(coins))")
    }
}

struct StarsView: View {
    var stars: Int
    var size: CGFloat = 14
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < stars ? Theme.C.gold : .black.opacity(0.2))
                    .shadow(color: i < stars ? Theme.C.goldEdge : .clear, radius: 0, y: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(arNum(stars)) نجوم")
    }
}

struct HintButton: View {
    enum Kind { case reveal, remove }
    var kind: Kind
    var cost: Int
    var enabled = true

    var body: some View {
        Tile3D(face: [Theme.C.panel, Theme.C.tileShade], edge: Theme.C.tileEdge, radius: 20) {
            HStack(spacing: 6) {
                Image(systemName: kind == .reveal ? "eye.fill" : "eraser.fill")
                    .foregroundStyle(kind == .reveal ? Theme.C.turquoise : Theme.C.button)
                Text(kind == .reveal ? "كشف حرف" : "حذف حرف")
                    .font(Theme.arabic(15, .bold)).foregroundStyle(Theme.C.panelText)
                    .lineLimit(1).fixedSize()
                CoinChip(amount: cost)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 44 + Theme.S.edge)
        .opacity(enabled ? 1 : 0.45)
    }
}

// MARK: - Buttons

struct GameButton: View {
    enum Style { case primary, gold, light }
    var title: String
    var icon: String? = nil
    var style: Style = .primary
    var height: CGFloat = 56

    var body: some View {
        Tile3D(face: face, edge: edge, radius: height / 2, depth: 5) {
            HStack(spacing: Theme.S.sm) {
                if let icon { Image(systemName: icon).font(.system(size: height * 0.32, weight: .bold)) }
                Text(title).font(Theme.arabic(height * 0.36, .bold))
            }
            .foregroundStyle(text)
            .offset(y: -1)
        }
        .frame(height: height + 5)
    }

    private var face: [Color] {
        switch style {
        case .primary: [Color(hex: 0xB8434F), Theme.C.buttonShade]
        case .gold: [Color(hex: 0xFFD978), Theme.C.goldShade]
        case .light: [Theme.C.panel, Theme.C.tileShade]
        }
    }
    private var edge: Color {
        switch style {
        case .primary: Theme.C.buttonEdge
        case .gold: Theme.C.goldEdge
        case .light: Theme.C.tileEdge
        }
    }
    private var text: Color {
        switch style {
        case .primary: Theme.C.onButton
        case .gold: Theme.C.onGold
        case .light: Theme.C.panelText
        }
    }
}

/// Kept for older call sites: maps to GameButton.
struct PrimaryButton: View {
    var title: String
    var secondary = false
    var body: some View { GameButton(title: title, style: secondary ? .light : .primary) }
}

/// Round glass button for the top bars (back, sound).
struct RoundIconButton: View {
    var systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Theme.C.coinPill.opacity(0.55), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Levels and packs

enum TileState { case locked, open, solved(Int) }

struct LevelMedallion: View {
    var number: Int
    var state: TileState
    var isNext = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                switch state {
                case .locked:
                    Tile3D(face: [Color(hex: 0xCFC4B2), Color(hex: 0xB7AA94)], edge: Color(hex: 0x857760), radius: 32, depth: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                    }
                case .open:
                    Tile3D(face: [Color(hex: 0xB8434F), Theme.C.buttonShade], edge: Theme.C.buttonEdge, radius: 32, depth: 4) {
                        Text(arNum(number)).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    }
                case .solved:
                    Tile3D(face: [Color(hex: 0xFFD978), Theme.C.goldShade], edge: Theme.C.goldEdge, radius: 32, depth: 4) {
                        Text(arNum(number)).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Theme.C.onGold)
                    }
                }
            }
            .frame(width: 64, height: 68)
            .background {
                if isNext {
                    Circle().fill(Theme.C.gold.opacity(0.6)).frame(width: 86, height: 86)
                        .scaleEffect(pulse ? 1.12 : 0.92).blur(radius: 6)
                }
            }
            if case .solved(let s) = state { StarsView(stars: s, size: 13) } else { Color.clear.frame(height: 15) }
        }
        .onAppear { if isNext { withAnimation(.easeInOut(duration: 1).repeatForever()) { pulse = true } } }
    }
}

/// Kept for the design catalog: same as LevelMedallion.
struct LevelTile: View {
    var number: Int
    var state: TileState
    var body: some View { LevelMedallion(number: number, state: state) }
}

struct ProgressBar: View {
    var fraction: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFD978), Theme.C.goldShade], startPoint: .top, endPoint: .bottom))
                    .frame(width: max(10, g.size.width * min(max(fraction, 0), 1)))
                    .opacity(fraction > 0 ? 1 : 0)
            }
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(fraction * 100))٪"))
    }
}

struct PackCard: View {
    var title: String
    var solved: Int
    var total: Int
    var stars: Int = 0
    var order: Int = 1
    var locked = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                SceneBackground(mood: .forPack(order: order), duneHeight: 0.45, animated: false)
                if locked {
                    Color.black.opacity(0.45)
                    Image(systemName: "lock.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(height: 110)
            .clipped()
            HStack(alignment: .center, spacing: Theme.S.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(Theme.F.title).foregroundStyle(Theme.C.panelText)
                    if locked {
                        Text("أكمل المجموعة السابقة لفتحها").font(Theme.F.caption).foregroundStyle(Theme.C.panelMuted)
                    } else {
                        ProgressBar(fraction: total == 0 ? 0 : Double(solved) / Double(total))
                    }
                }
                Spacer()
                if !locked {
                    VStack(spacing: 2) {
                        Text("\(arNum(solved))/\(arNum(total))").font(Theme.F.number).foregroundStyle(Theme.C.panelText)
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(Theme.C.goldShade)
                            Text(arNum(stars)).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Theme.C.panelMuted)
                        }
                    }
                }
            }
            .padding(Theme.S.lg)
            .background(Theme.C.panel)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.R.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.R.card).stroke(Theme.C.gold, lineWidth: 2))
        .cardShadow()
    }
}

/// Top bar over a scene: back button, title, trailing slot.
struct SceneTopBar<Trailing: View>: View {
    var title: String
    var back: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title).font(Theme.F.title).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            HStack {
                if let back {
                    Button(action: back) { RoundIconButton(systemName: "chevron.backward") }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel("رجوع")
                        .accessibilityIdentifier("nav.back")
                } else { Color.clear.frame(width: 44, height: 44) }
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, Theme.S.lg)
        .frame(height: Theme.S.topbar)
    }
}

// MARK: - Celebration

/// Confetti burst drawn with Canvas; runs ~3 s.
struct Confetti: View {
    @State private var start = Date()
    private let colors: [Color] = [Color(hex: 0xF2C55C), Color(hex: 0x9E3440), Color(hex: 0x187770), .white, Color(hex: 0xF08A4B)]

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                guard t < 3 else { return }
                var rng = SeededRNG(seed: "confetti")
                for i in 0..<90 {
                    let vx = (Double(rng.next() % 1000) / 1000 - 0.5) * 420
                    let vy = -Double(rng.next() % 1000) / 1000 * 650 - 250
                    let x = size.width / 2 + vx * t
                    let y = size.height * 0.42 + vy * t + 520 * t * t
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(t * Double(4 + i % 5)))
                    c.opacity = max(0, 1 - t / 3)
                    c.fill(Path(CGRect(x: -4, y: -2.5, width: 8, height: 5)), with: .color(colors[i % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
