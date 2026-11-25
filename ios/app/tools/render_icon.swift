// Renders the app icon (1024×1024) from the game's own components on macOS.
// swiftc -parse-as-library tools/render_icon.swift Sources/Design/*.swift Sources/Game/ArabicText.swift -o /tmp/icon
// /tmp/icon Resources/Fonts/NotoNaskhArabic.ttf icon/AppIcon.png
import SwiftUI
import AppKit
import CoreText

struct IconArt: View {
    let s: CGFloat = 1024
    var body: some View {
        let t: CGFloat = 232            // tile size
        let gap: CGFloat = 18
        let step = t + gap
        // لغز across (right → left) on top, لعب down from the shared ل at the top-right.
        let x0 = s / 2 + step               // column of the shared ل (rightmost)
        let y0 = s / 2 - step        // top row
        ZStack {
            SceneBackground(mood: .sunset, duneHeight: 0.30, animated: false, pattern: false)
            RadialGradient(colors: [.clear, .black.opacity(0.30)], center: .center, startRadius: 320, endRadius: 740)
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    tile(["ل", "غ", "ز"][i], gold: true, t).position(x: x0 - CGFloat(i) * step, y: y0)
                }
                ForEach(1..<3, id: \.self) { i in
                    tile(["ل", "ع", "ب"][i], gold: false, t).position(x: x0, y: y0 + CGFloat(i) * step)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 24, y: 16)
        }
        .frame(width: s, height: s)
        .environment(\.layoutDirection, .leftToRight)
    }

    func tile(_ letter: String, gold: Bool, _ t: CGFloat) -> some View {
        Tile3D(face: gold ? [Color(hex: 0xFFD978), Theme.C.goldShade] : [Theme.C.tile, Theme.C.tileShade],
               edge: gold ? Theme.C.goldEdge : Theme.C.tileEdge, radius: t * 0.18, depth: t * 0.09) {
            Text(letter)
                .font(Theme.arabic(t * 0.62, .bold))
                .foregroundStyle(Theme.C.tileText)
                .offset(y: -t * 0.05)
        }
        .frame(width: t, height: t + t * 0.09)
    }
}

@main
struct RenderIcon {
    @MainActor static func main() {
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, .process, nil)
        let r = ImageRenderer(content: IconArt())
        r.scale = 1
        guard let img = r.cgImage else { print("render failed"); exit(1) }
        let rep = NSBitmapImageRep(cgImage: img)
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        print("ok", img.width, img.height)
    }
}
