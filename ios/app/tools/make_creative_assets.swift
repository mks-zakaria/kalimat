// App Store creative assets (iOS 27+): product page header (21:9) and search results image (3:2).
// Specs (developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications):
//   header 3840×1646, art safe area 1646×661 at (1097, 493)
//   search 3840×2560, art safe area 2168×1030 at (836, 765)
//   no alpha, no logos, short localized text only, 4+ content.
// swiftc -parse-as-library tools/make_creative_assets.swift Sources/Design/*.swift Sources/Game/ArabicText.swift -o /tmp/creative
// /tmp/creative Resources/Fonts/NotoNaskhArabic.ttf ../store/creative
import SwiftUI
import AppKit
import CoreText

struct Spec { let name: String; let size: CGSize; let safe: CGRect }
let header = Spec(name: "header", size: CGSize(width: 3840, height: 1646), safe: CGRect(x: 1097, y: 493, width: 1646, height: 661))
let search = Spec(name: "search", size: CGSize(width: 3840, height: 2560), safe: CGRect(x: 836, y: 765, width: 2168, height: 1030))

struct Copy { let code: String; let line: String; let rtl: Bool }
let copies = [Copy(code: "ar", line: "ألغاز عربية بنكهة خليجية", rtl: true),
              Copy(code: "en", line: "Arabic word puzzles", rtl: false)]

/// One gold / ivory letter tile, as in the game.
struct Tile: View {
    let letter: String; let gold: Bool; let t: CGFloat
    var body: some View {
        Tile3D(face: gold ? [Color(hex: 0xFFD978), Theme.C.goldShade] : [Theme.C.tile, Theme.C.tileShade],
               edge: gold ? Theme.C.goldEdge : Theme.C.tileEdge, radius: t * 0.18, depth: t * 0.09) {
            Text(letter).font(Theme.arabic(t * 0.6, .bold)).foregroundStyle(Theme.C.tileText).offset(y: -t * 0.05)
        }
        .frame(width: t, height: t + t * 0.09)
    }
}

/// The key art that must stay inside the safe area: لغز across / لعب down + one short line.
struct KeyArt: View {
    let copy: Copy; let box: CGSize
    var body: some View {
        let t = min(box.height * 0.28, box.width * 0.12)          // 3 tiles + gaps + edge fit the safe height
        let step = t * 1.08
        HStack(spacing: box.width * 0.06) {
            ZStack(alignment: .topTrailing) {
                // لعب runs down from the shared ل, لغز runs right-to-left from it
                ForEach(0..<3, id: \.self) { i in
                    Tile(letter: ["ل", "غ", "ز"][i], gold: true, t: t).offset(x: -CGFloat(i) * step)
                }
                ForEach(1..<3, id: \.self) { i in
                    Tile(letter: ["ل", "ع", "ب"][i], gold: false, t: t).offset(y: CGFloat(i) * step)
                }
            }
            .frame(width: t + 2 * step, height: t + 2 * step + t * 0.09, alignment: .topTrailing)
            .environment(\.layoutDirection, .leftToRight)            // the word must read لغز in every locale
            .shadow(color: .black.opacity(0.45), radius: t * 0.12, y: t * 0.08)

            Text(copy.line)
                .font(copy.rtl ? Theme.arabic(t * 0.5, .bold) : .system(size: t * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(copy.rtl ? .trailing : .leading)
                .lineLimit(2).minimumScaleFactor(0.5)
                .frame(maxWidth: box.width * 0.48, alignment: copy.rtl ? .trailing : .leading)
                .shadow(color: .black.opacity(0.4), radius: t * 0.08, y: t * 0.04)
        }
        .environment(\.layoutDirection, copy.rtl ? .rightToLeft : .leftToRight)
        .frame(width: box.width, height: box.height)
    }
}

struct Asset: View {
    let spec: Spec; let copy: Copy; let showSafe: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            // full-bleed scene: shows on wide screens, cropped elsewhere
            SceneBackground(mood: .sunset, duneHeight: 0.34, animated: false)
                .frame(width: spec.size.width, height: spec.size.height)
            RadialGradient(colors: [.black.opacity(0.0), .black.opacity(0.28)], center: UnitPoint(x: 0.5, y: 0.47),
                           startRadius: spec.safe.width * 0.45, endRadius: spec.size.width * 0.6)
            KeyArt(copy: copy, box: spec.safe.size)
                .offset(x: spec.safe.minX, y: spec.safe.minY)
            if showSafe {
                Rectangle().stroke(Color.green, lineWidth: 8)
                    .frame(width: spec.safe.width, height: spec.safe.height)
                    .offset(x: spec.safe.minX, y: spec.safe.minY)
            }
        }
        .frame(width: spec.size.width, height: spec.size.height, alignment: .topLeading)
        .clipped()
        .environment(\.layoutDirection, .leftToRight)
    }
}

@main
struct MakeCreative {
    @MainActor static func main() {
        let a = CommandLine.arguments
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: a[1]) as CFURL, .process, nil)
        try? FileManager.default.createDirectory(atPath: a[2] + "/preview", withIntermediateDirectories: true)
        for spec in [header, search] {
            for copy in copies {
                for safe in [false, true] {
                    let r = ImageRenderer(content: Asset(spec: spec, copy: copy, showSafe: safe))
                    r.scale = 1
                    guard let cg = r.cgImage else { print("render failed"); exit(1) }
                    let out = safe ? "\(a[2])/preview/\(spec.name)-\(copy.code)-safe.png" : "\(a[2])/\(spec.name)-\(copy.code).png"
                    try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
                        .write(to: URL(fileURLWithPath: out))
                    print(out, cg.width, cg.height)
                }
            }
        }
    }
}
