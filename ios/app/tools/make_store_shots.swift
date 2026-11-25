// Frames raw 6.9" captures (UITests/StoreScreenshots) into App Store marketing images, 1320×2868.
// swiftc -parse-as-library tools/make_store_shots.swift Sources/Design/*.swift Sources/Game/ArabicText.swift -o /tmp/shots
// /tmp/shots Resources/Fonts/NotoNaskhArabic.ttf <raw dir> <out dir> [width height]
import SwiftUI
import AppKit
import CoreText

struct Shot { let file: String; let title: String; let sub: String; let mood: SceneMood }

let shots = [
    Shot(file: "2-crossword", title: "كلمات متقاطعة عربية", sub: "تعريفات من الخليج والعالم العربي بإملاء صحيح", mood: .sunset),
    Shot(file: "3-wordsearch", title: "وطريقة ثانية للعب", sub: "ارسم خطًا فوق الكلمة المخفية في أي اتجاه", mood: .dawn),
    Shot(file: "4-complete", title: "اكتشف معدّل ذكائك", sub: "يتحدّث بعد كل لغز حسب سرعتك في الحل", mood: .night),
    Shot(file: "1-home", title: "ألغاز بنكهة خليجية", sub: "تعمل دون إنترنت، وبلا حساب أو تسجيل", mood: .sunset),
    Shot(file: "6-packs", title: "٢٥٠ لغزًا في ٨ مجموعات", sub: "من السهل إلى تحدّي الخبراء", mood: .day),
]

struct Frame: View {
    let shot: Shot
    let image: NSImage
    // Canvas: 1320x2868 (6.9" iPhone, the original set) unless args 4/5 give another size,
    // e.g. 2064x2752 for the 13" iPad or 1398x2034 for the iPhone Duo.
    var W: CGFloat = 1320, H: CGFloat = 2868

    var body: some View {
        let s = W / 1320                      // type and spacing scale with the canvas width
        let aspect = image.size.width / image.size.height
        let isPhone = W == 1320 && H == 2868
        // The iPhone set keeps its exact original geometry; other canvases fit the device below the text.
        let top = 150 * s, textBlock = 330 * s, gap = 26 * s
        var devH: CGFloat = isPhone ? 2180 : H - top - textBlock - gap - 70 * s
        var devW = devH * aspect
        if devW > W * 0.86 { devW = W * 0.86; devH = devW / aspect }
        let radius = isPhone ? 96 : devW * (aspect > 0.7 ? 0.035 : 0.07)
        return ZStack(alignment: .top) {
            LinearGradient(colors: shot.mood.sky, startPoint: .top, endPoint: .bottom)
            GirihPattern(cell: 120 * s).stroke(Color.white.opacity(0.10), lineWidth: 2.5 * s)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 34 * s) {
                Text(shot.title)
                    .font(Theme.arabic(108 * s, .bold)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8 * s, y: 4 * s)
                Text(shot.sub)
                    .font(Theme.arabic(52 * s, .bold)).foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center).lineSpacing(10 * s)
                    .frame(width: W - 200 * s)
                    .fixedSize(horizontal: false, vertical: true)
                Image(nsImage: image)
                    .resizable().interpolation(.high)
                    .frame(width: devW, height: devH)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color(hex: 0x15121F), lineWidth: 22 * s))
                    .overlay(RoundedRectangle(cornerRadius: radius + 10 * s, style: .continuous).stroke(Theme.C.gold.opacity(0.85), lineWidth: 6 * s).padding(-14 * s))
                    .shadow(color: .black.opacity(0.45), radius: 50 * s, y: 30 * s)
                    .padding(.top, gap)
            }
            .padding(.top, top)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .frame(width: W, height: H)
        .clipped()
    }
}

@main
struct MakeStoreShots {
    @MainActor static func main() {
        let a = CommandLine.arguments
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: a[1]) as CFURL, .process, nil)
        try? FileManager.default.createDirectory(atPath: a[3], withIntermediateDirectories: true)
        for (i, s) in shots.enumerated() {
            guard let img = NSImage(contentsOfFile: "\(a[2])/\(s.file).png") else { print("missing", s.file); exit(1) }
            var frame = Frame(shot: s, image: img)
            if a.count > 5, let w = Double(a[4]), let h = Double(a[5]) { frame.W = w; frame.H = h }
            let r = ImageRenderer(content: frame)
            r.scale = 1
            guard let cg = r.cgImage else { print("render failed"); exit(1) }
            let out = "\(a[3])/\(i + 1)-\(s.file.split(separator: "-").last!).png"
            try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
            print(out, cg.width, cg.height)
        }
    }
}
