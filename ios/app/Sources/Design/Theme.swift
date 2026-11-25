import SwiftUI

/// Design tokens — from replica/design/tokens.json (v2, game look).
/// Role names match the JSON; change values there first, re-run contrast.py, then here.
enum Theme {
    enum C {
        // v1 roles (still used for text and states)
        static let bg = Color(hex: 0xF7F2E8)
        static let surface = Color(hex: 0xFFFDF8)
        static let border = Color(hex: 0xE4DACB)
        static let borderInput = Color(hex: 0x8A7F70)
        static let text = Color(hex: 0x1E2230)
        static let textMuted = Color(hex: 0x5F6573)
        static let accent = Color(hex: 0x8C2F39)
        static let onAccent = Color(hex: 0xFFFFFF)
        static let danger = Color(hex: 0xB3261E)
        static let success = Color(hex: 0x2E6B4F)
        static let warning = Color(hex: 0x8A5A00)

        // v2 game roles
        static let panel = Color(hex: 0xFFF8EC)
        static let panelText = Color(hex: 0x2B1D12)
        static let panelMuted = Color(hex: 0x6B5A48)
        static let tile = Color(hex: 0xFFF6E6)
        static let tileShade = Color(hex: 0xF1E2C6)
        static let tileEdge = Color(hex: 0x9C7E52)
        static let tileText = Color(hex: 0x2B1D12)
        static let gold = Color(hex: 0xF2C55C)
        static let goldShade = Color(hex: 0xE2A93E)
        static let goldEdge = Color(hex: 0xB9862E)
        static let onGold = Color(hex: 0x2B1D12)
        static let turquoise = Color(hex: 0x187770)
        static let turquoiseEdge = Color(hex: 0x0E4F4A)
        static let onTurquoise = Color(hex: 0xFFFFFF)
        static let button = Color(hex: 0x9E3440)
        static let buttonShade = Color(hex: 0x7E2731)
        static let buttonEdge = Color(hex: 0x5C1B23)
        static let onButton = Color(hex: 0xFFFFFF)
        static let slot = Color(hex: 0xEDE0C8)
        static let slotText = Color(hex: 0x2B1D12)
        static let skyText = Color.white
        static let coinPill = Color(hex: 0x2B1D12)
    }

    enum R {
        static let cell: CGFloat = 8
        static let key: CGFloat = 12
        static let card: CGFloat = 22
    }

    enum S {
        static let xs: CGFloat = 4, sm: CGFloat = 8, md: CGFloat = 12, lg: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32
        static let cellMax: CGFloat = 44, cellGap: CGFloat = 4, key: CGFloat = 46, slot: CGFloat = 44, topbar: CGFloat = 52
        static let edge: CGFloat = 4          // height of a tile's 3D bottom edge
    }

    /// Noto Naskh Arabic (SIL OFL 1.1), bundled as a variable font.
    static let arabicFamily = "Noto Naskh Arabic"

    static func arabic(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(arabicFamily, size: size).weight(weight)
    }

    enum F {
        static let caption = Theme.arabic(13, .semibold)
        static let body = Theme.arabic(17)
        static let clue = Theme.arabic(21, .bold)
        static let title = Theme.arabic(22, .bold)
        static let cell = Theme.arabic(22, .bold)
        static let key = Theme.arabic(26, .bold)
        static let display = Theme.arabic(56, .bold)
        static let number = Font.system(size: 17, weight: .heavy, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension View {
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.10), radius: 2, y: 1)
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }
}

extension View {
    /// Caps content at a comfortable reading width and centres it. A no-op on every iPhone
    /// (all narrower than 720 pt); on iPad it stops buttons, clue cards and keys stretching
    /// across a 13-inch screen.
    func readableWidth(_ max: CGFloat = 720) -> some View {
        frame(maxWidth: max).frame(maxWidth: .infinity)
    }
}
