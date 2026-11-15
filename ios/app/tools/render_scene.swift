// Renders the four scene moods side by side (phone size) on macOS, to judge the sky design.
// swiftc -parse-as-library tools/render_scene.swift Sources/Design/*.swift Sources/Game/ArabicText.swift -o /tmp/scene && /tmp/scene out.png
import SwiftUI
import AppKit

@main
struct RenderScene {
    @MainActor static func main() {
        let art = HStack(spacing: 12) {
            ForEach(SceneMood.allCases, id: \.self) { m in
                SceneBackground(mood: m, duneHeight: 0.3, animated: false).frame(width: 414, height: 896)
            }
        }
        .padding(12).background(Color.black)
        let r = ImageRenderer(content: art)
        r.scale = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2])! : 1
        guard let img = r.cgImage else { print("render failed"); exit(1) }
        try! NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("ok")
    }
}
