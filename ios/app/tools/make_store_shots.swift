// Frames raw 6.9" captures (UITests/StoreScreenshots) into App Store marketing images, 1320×2868.
// swiftc -parse-as-library tools/make_store_shots.swift Sources/Design/*.swift Sources/Game/ArabicText.swift -o /tmp/shots
// /tmp/shots Resources/Fonts/NotoNaskhArabic.ttf <raw dir> <out dir>
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
    let W: CGFloat = 1320, H: CGFloat = 2868

    var body: some View {
        let phoneH: CGFloat = 2180, phoneW = phoneH * 1320 / 2868
        ZStack(alignment: .top) {
            LinearGradient(colors: shot.mood.sky, startPoint: .top, endPoint: .bottom)
            GirihPattern(cell: 120).stroke(Color.white.opacity(0.10), lineWidth: 2.5)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 34) {
                Text(shot.title)
                    .font(Theme.arabic(108, .bold)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                Text(shot.sub)
                    .font(Theme.arabic(52, .bold)).foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center).lineSpacing(10)
                    .frame(width: 1120)
                    .fixedSize(horizontal: false, vertical: true)
                Image(nsImage: image)
                    .resizable().interpolation(.high)
                    .frame(width: phoneW, height: phoneH)
                    .clipShape(RoundedRectangle(cornerRadius: 96, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 96, style: .continuous).stroke(Color(hex: 0x15121F), lineWidth: 22))
                    .overlay(RoundedRectangle(cornerRadius: 106, style: .continuous).stroke(Theme.C.gold.opacity(0.85), lineWidth: 6).padding(-14))
                    .shadow(color: .black.opacity(0.45), radius: 50, y: 30)
                    .padding(.top, 26)
            }
            .padding(.top, 150)
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
            let r = ImageRenderer(content: Frame(shot: s, image: img))
            r.scale = 1
            guard let cg = r.cgImage else { print("render failed"); exit(1) }
            let out = "\(a[3])/\(i + 1)-\(s.file.split(separator: "-").last!).png"
            try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
            print(out, cg.width, cg.height)
        }
    }
}
