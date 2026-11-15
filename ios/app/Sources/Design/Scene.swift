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
    @State private var drift = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                LinearGradient(colors: mood.sky, startPoint: .top, endPoint: .bottom)

                if mood.hasStars { Stars().opacity(mood == .night ? 0.9 : 0.4) }

                MoonPhaseArc(mood: mood, animated: animated)

                // sun sitting on the horizon (half behind the dunes); at night the moon arc is the light
                if mood != .night {
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
/// The lunar cycle as one soft arc across the sky: thin crescent → half → gibbous → full
/// (largest, in the middle) → back. Each moon shows its dark disk faintly and its lit part in
/// warm moonlight; a faint orbit line ties them together.
struct MoonPhaseArc: View {
    var mood: SceneMood
    var animated = true
    static let phases: [CGFloat] = [0.07, 0.16, 0.26, 0.37, 0.5, 0.63, 0.74, 0.84, 0.93]
    @State private var glow = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let n = Self.phases.count
            let top = h * 0.105, sag = h * 0.045
            let point: (CGFloat) -> CGPoint = { u in
                CGPoint(x: w * (0.09 + 0.82 * u), y: top + sag * pow(2 * u - 1, 2))
            }
            ZStack {
                // orbit line
                Path { p in
                    for i in 0...40 {
                        let pt = point(CGFloat(i) / 40)
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                }
                .stroke(Color.white.opacity(0.10 * strength), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))

                ForEach(0..<n, id: \.self) { i in
                    let u = CGFloat(i) / CGFloat(n - 1)
                    let phase = Self.phases[i]
                    let fullness = 1 - abs(phase - 0.5) * 2                // 0 at the ends, 1 for the full moon
                    let r = w * (0.019 + 0.018 * fullness)
                    let c = point(u)
                    ZStack {
                        Circle().fill(Color.white.opacity(0.07 * strength))
                        Circle().stroke(Color.white.opacity(0.14 * strength), lineWidth: 0.8)
                        MoonLit(phase: phase)
                            .fill(LinearGradient(colors: [Color(hex: 0xFFF8E1), Color(hex: 0xF6DFA8)],
                                                 startPoint: .top, endPoint: .bottom))
                            .opacity(0.75 * strength)
                    }
                    .frame(width: r * 2, height: r * 2)
                    .shadow(color: Color(hex: 0xFFE9B0).opacity((phase == 0.5 && glow ? 0.9 : 0.45) * strength),
                            radius: phase == 0.5 ? (glow ? 16 : 9) : 5)
                    .position(c)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { if animated { withAnimation(.easeInOut(duration: 3.5).repeatForever()) { glow = true } } }
    }

    /// Moonlight is strongest at night, softest in daylight.
    private var strength: Double {
        switch mood {
        case .night: 1
        case .dawn, .sunset: 0.8
        case .day: 0.55
        }
    }
}

/// The lit part of the moon for a phase, drawn in the unit square of its frame.
struct MoonLit: Shape {
    var phase: CGFloat
    func path(in r: CGRect) -> Path {
        MoonPhasesPattern.moon(center: CGPoint(x: r.midX, y: r.midY), radius: min(r.width, r.height) / 2, phase: phase)
    }
}

enum MoonPhasesPattern {
    /// Outline of the lit part of the moon. `phase` 0 = new, 0.25 = first quarter, 0.5 = full,
    /// 0.75 = last quarter. The new moon is drawn as a plain circle so the rhythm stays visible.
    static func moon(center c: CGPoint, radius r: CGFloat, phase: CGFloat) -> Path {
        if phase == 0 || phase == 0.5 {
            return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }
        let waxing = phase < 0.5
        let t = waxing ? phase : 1 - phase
        let e = r * cos(2 * .pi * t)                // terminator: half an ellipse of width e
        let side: CGFloat = waxing ? 1 : -1         // waxing lit on the right, waning on the left
        var p = Path()
        let steps = 24
        for i in 0...steps {                        // limb: top → bottom along the lit edge
            let a = -CGFloat.pi / 2 + CGFloat.pi * CGFloat(i) / CGFloat(steps)
            let pt = CGPoint(x: c.x + side * r * cos(a), y: c.y + r * sin(a))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        for i in 0...steps {                        // terminator: bottom → top
            let a = CGFloat.pi / 2 - CGFloat.pi * CGFloat(i) / CGFloat(steps)
            p.addLine(to: CGPoint(x: c.x + side * e * cos(a), y: c.y + r * sin(a)))
        }
        p.closeSubpath()
        return p
    }
}
