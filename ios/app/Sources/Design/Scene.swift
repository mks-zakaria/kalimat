import SwiftUI

/// Original desert artwork, drawn in code: sky, sun or moon, stars, three dune
/// layers, a palm, and a faint eight-point-star pattern. One mood per pack.
enum SceneMood: Int, CaseIterable {
    case dawn, day, sunset, night

    static func forPack(order: Int) -> SceneMood { SceneMood(rawValue: (max(order, 1) - 1) % 4)! }

    var sky: [Color] {
        switch self {
        case .dawn: [Color(hex: 0x4B3A6E), Color(hex: 0x9C5B7F), Color(hex: 0xF0A27A)]
        case .day: [Color(hex: 0x2F6FA8), Color(hex: 0x5FA3D6), Color(hex: 0xBFE0F2)]
        case .sunset: [Color(hex: 0x2A1F4D), Color(hex: 0x8A3B5C), Color(hex: 0xF08A4B)]
        case .night: [Color(hex: 0x0E1430), Color(hex: 0x1B2340), Color(hex: 0x34406B)]
        }
    }
    var dunes: [Color] {   // back -> front
        switch self {
        case .dawn: [Color(hex: 0xC98B73), Color(hex: 0xDDA27D), Color(hex: 0xEBBE8E)]
        case .day: [Color(hex: 0xE2B77C), Color(hex: 0xEBC68D), Color(hex: 0xF3D7A4)]
        case .sunset: [Color(hex: 0x9B4F48), Color(hex: 0xC06B4E), Color(hex: 0xDB8C5C)]
        case .night: [Color(hex: 0x2D2F55), Color(hex: 0x3B3C66), Color(hex: 0x4C4B76)]
        }
    }
    var sun: Color {
        switch self {
        case .dawn: Color(hex: 0xFFD3A1)
        case .day: Color(hex: 0xFFF3C4)
        case .sunset: Color(hex: 0xFFB45E)
        case .night: Color(hex: 0xF4EFD9)
        }
    }
    var hasStars: Bool { self == .night || self == .dawn }
    var palm: Color { dunes[0].opacity(0.9) }
}

struct SceneBackground: View {
    var mood: SceneMood = .sunset
    /// 0...1 — how much of the height the dunes take.
    var duneHeight: CGFloat = 0.32
    var animated = true
    /// Faint girih pattern in the upper sky (off for the app icon).
    var pattern = true
    @State private var drift = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                LinearGradient(colors: mood.sky, startPoint: .top, endPoint: .bottom)

                if mood.hasStars { Stars().opacity(mood == .night ? 0.9 : 0.4) }

                if pattern {
                    GirihSky(mood: mood)
                        .frame(height: h * 0.6)
                        .frame(maxHeight: .infinity, alignment: .top)
                }

                // sun sitting on the horizon (half behind the dunes) / crescent moon high in the night sky
                if mood == .night {
                    Circle()
                        .fill(mood.sun)
                        .frame(width: w * 0.16)
                        .mask {
                            Circle().frame(width: w * 0.16)
                                .overlay(Circle().frame(width: w * 0.15).offset(x: w * 0.05, y: -w * 0.03).blendMode(.destinationOut))
                                .compositingGroup()
                        }
                        .shadow(color: mood.sun.opacity(0.7), radius: 18)
                        .position(x: w * 0.22, y: h * 0.16 + (drift ? -4 : 4))
                } else {
                    Circle()
                        .fill(mood.sun)
                        .frame(width: w * 0.3)
                        .shadow(color: mood.sun.opacity(0.8), radius: 40)
                        .position(x: w * 0.3, y: h * (1 - duneHeight * 0.92) + (drift ? -5 : 5))
                }

                Dune(phase: 0.15, amplitude: 0.30).fill(mood.dunes[0])
                    .frame(height: h * duneHeight * 1.05).frame(maxHeight: .infinity, alignment: .bottom)
                Palm().fill(mood.palm)
                    .frame(width: w * 0.22, height: h * duneHeight * 0.95)
                    .position(x: w * 0.82, y: h * (1 - duneHeight * 0.78))
                Dune(phase: 0.55, amplitude: 0.35).fill(mood.dunes[1])
                    .frame(height: h * duneHeight * 0.8).frame(maxHeight: .infinity, alignment: .bottom)
                Dune(phase: 0.9, amplitude: 0.25).fill(mood.dunes[2])
                    .frame(height: h * duneHeight * 0.55).frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .ignoresSafeArea()
        .onAppear { if animated { withAnimation(.easeInOut(duration: 6).repeatForever()) { drift = true } } }
        .accessibilityHidden(true)
    }
}

/// A smooth dune line across the top of its frame.
struct Dune: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        let top = r.minY + r.height * amplitude
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: top + r.height * 0.15 * sin(phase * 6)))
        let steps = 3
        for i in 1...steps {
            let x = r.minX + r.width * CGFloat(i) / CGFloat(steps)
            let y = top + r.height * 0.18 * sin(phase * 6 + CGFloat(i) * 1.9)
            let cx = x - r.width / CGFloat(steps) / 2
            let cy = top - r.height * amplitude * 0.9 * (i % 2 == 0 ? 0.4 : 1)
            p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Simple date-palm silhouette: curved trunk and fronds.
struct Palm: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let base = CGPoint(x: r.midX, y: r.maxY)
        let top = CGPoint(x: r.midX + r.width * 0.08, y: r.minY + r.height * 0.22)
        // trunk
        p.move(to: CGPoint(x: base.x - r.width * 0.035, y: base.y))
        p.addQuadCurve(to: CGPoint(x: top.x - r.width * 0.02, y: top.y),
                       control: CGPoint(x: r.midX - r.width * 0.12, y: r.midY))
        p.addLine(to: CGPoint(x: top.x + r.width * 0.02, y: top.y))
        p.addQuadCurve(to: CGPoint(x: base.x + r.width * 0.035, y: base.y),
                       control: CGPoint(x: r.midX - r.width * 0.06, y: r.midY))
        p.closeSubpath()
        // fronds
        let angles: [CGFloat] = [-160, -130, -100, -60, -30, -5, 20]
        for a in angles {
            let rad = a * .pi / 180
            let len = r.width * 0.55
            let tip = CGPoint(x: top.x + cos(rad) * len, y: top.y + sin(rad) * len * 0.55 + len * 0.25)
            let ctrl = CGPoint(x: top.x + cos(rad) * len * 0.5, y: top.y + sin(rad) * len * 0.6 - len * 0.12)
            p.move(to: top)
            p.addQuadCurve(to: tip, control: ctrl)
            p.addQuadCurve(to: top, control: CGPoint(x: ctrl.x, y: ctrl.y + len * 0.12))
        }
        return p
    }
}

/// Seeded twinkling-free star field (static, cheap).
struct Stars: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: "stars")
            for _ in 0..<70 {
                let x = CGFloat(rng.next() % 1000) / 1000 * size.width
                let y = CGFloat(rng.next() % 1000) / 1000 * size.height * 0.6
                let s = CGFloat(rng.next() % 100) / 100 * 2 + 0.6
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(.white.opacity(0.85)))
            }
        }
    }
}

/// Tiled eight-point stars (two overlapping squares) — a classic geometric motif.
/// Faint girih "star and cross" pattern for the upper sky: eight-pointed stars (never six),
/// each with an octagon at its heart and short bands to its neighbours, so the gaps read as
/// crosses. Drawn as a carved-plaster relief: a light edge with a soft shadow under it.
struct GirihPattern: Shape {
    var cell: CGFloat = 58

    func path(in r: CGRect) -> Path {
        var p = Path()
        let R = cell * 0.40, inner = R * 0.6, core = R * 0.3
        var y = r.minY
        while y < r.maxY + cell {
            var x = r.minX
            while x < r.maxX + cell {
                let c = CGPoint(x: x, y: y)
                // eight-pointed star outline: 16 vertices, tips on the axes and diagonals
                var star = Path()
                for k in 0..<16 {
                    let a = CGFloat(k) * .pi / 8 - .pi / 2
                    let rad = k % 2 == 0 ? R : inner
                    let pt = CGPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad)
                    k == 0 ? star.move(to: pt) : star.addLine(to: pt)
                }
                star.closeSubpath()
                p.addPath(star)
                // octagon at the heart
                var oct = Path()
                for k in 0..<8 {
                    let a = CGFloat(k) * .pi / 4 + .pi / 8
                    let pt = CGPoint(x: c.x + cos(a) * core, y: c.y + sin(a) * core)
                    k == 0 ? oct.move(to: pt) : oct.addLine(to: pt)
                }
                oct.closeSubpath()
                p.addPath(oct)
                // bands to the right and lower neighbours (tip to tip)
                p.move(to: CGPoint(x: c.x + R, y: c.y)); p.addLine(to: CGPoint(x: c.x + cell - R, y: c.y))
                p.move(to: CGPoint(x: c.x, y: c.y + R)); p.addLine(to: CGPoint(x: c.x, y: c.y + cell - R))
                x += cell
            }
            y += cell
        }
        return p
    }
}

/// The girih pattern as faint relief over the upper sky, fading out toward the dunes.
struct GirihSky: View {
    var mood: SceneMood

    var body: some View {
        let light: Double = mood == .day ? 0.16 : 0.12
        ZStack {
            GirihPattern().stroke(Color.black.opacity(light * 0.9), lineWidth: 1.2).offset(x: 0.6, y: 1)
            GirihPattern().stroke(Color.white.opacity(light), lineWidth: 1)
        }
        .mask(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .white.opacity(0.8), location: 0.35),
                                     .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }
}
