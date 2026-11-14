// macOS-only design check: renders DesignCatalog to PNG (no iOS simulator needed).
// swiftc -parse-as-library tools/render_catalog.swift Sources/Design/*.swift Sources/Features/Catalog/*.swift -o /tmp/render
import SwiftUI
import AppKit
import CoreText

@main
struct Render {
    @MainActor static func main() {
        let font = URL(fileURLWithPath: CommandLine.arguments[1])
        CTFontManagerRegisterFontsForURL(font as CFURL, .process, nil)
        let r = ImageRenderer(content: DesignCatalog().frame(width: 390))
        r.scale = 2
        guard let img = r.nsImage, let tiff = img.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            print("render failed"); exit(1)
        }
        try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        print("ok", img.size)
    }
}
