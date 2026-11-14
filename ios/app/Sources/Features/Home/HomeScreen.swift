import SwiftUI

/// S01 — scene, logo emblem, continue card, packs.
struct HomeScreen: View {
    let packs: [Pack]
    let wsPacks: [Pack]
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var store
    @State private var appear = false

    var body: some View {
        let next = nextLevel(in: packs, store: store)
        ZStack {
            SceneBackground(mood: next.map { .forPack(order: $0.1.order) } ?? .night, duneHeight: 0.34)

            VStack(spacing: Theme.S.lg) {
                HStack {
                    Spacer()
                    TopBarActions()
                }
                .padding(.horizontal, Theme.S.lg)

                Spacer(minLength: 0)
                Emblem()
                    .scaleEffect(appear ? 1 : 0.8)
                    .opacity(appear ? 1 : 0)
                Spacer(minLength: 0)

                VStack(spacing: Theme.S.md) {
                    if let (level, pack) = next {
                        Button { path.append(.board(level, pack)) } label: {
                            VStack(spacing: 2) {
                                GameButton(title: store.file.levels.isEmpty ? "ابدأ اللعب" : "تابع اللعب",
                                           icon: "play.fill", style: .gold, height: 64)
                            }
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("home.play")
                        Text("\(pack.titleAr) · لغز \(arNum(level.number))")
                            .font(Theme.F.caption).foregroundStyle(.white)
                            .padding(.horizontal, Theme.S.md).padding(.vertical, 4)
                            .background(Theme.C.coinPill.opacity(0.6), in: Capsule())
                    } else if !packs.isEmpty {
                        Text("أنهيت كل الألغاز! انتظر مجموعات جديدة قريبًا")
                            .font(Theme.F.body).foregroundStyle(.white).multilineTextAlignment(.center)
                    }
                    HStack(spacing: Theme.S.md) {
                        Button {
                            if let (level, pack) = nextLevel(in: wsPacks, store: store) {
                                path.append(.board(level, pack))
                            } else {
                                path.append(.packs(.wordSearch))
                            }
                        } label: {
                            GameButton(title: "كلمات مخفية", icon: "scribble.variable", style: .primary, height: 52)
                        }
                        .buttonStyle(PressStyle())
                        .disabled(wsPacks.isEmpty)
                        .accessibilityIdentifier("home.wordsearch")
                        Button { path.append(.packs(.crossword)) } label: {
                            GameButton(title: "المجموعات", icon: "square.grid.2x2.fill", style: .light, height: 52)
                        }
                        .buttonStyle(PressStyle())
                        .disabled(packs.isEmpty)
                        .accessibilityIdentifier("home.packs")
                    }
                }
                .padding(.horizontal, Theme.S.xl)
                .padding(.bottom, Theme.S.xl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appear = true } }
    }
}

/// The logo: "كلمات" on a gold eight-point star with a 3D rim, plus the tagline.
struct Emblem: View {
    @State private var spin = false

    var body: some View {
        VStack(spacing: Theme.S.md) {
            ZStack {
                EightPointStar()
                    .fill(Theme.C.goldEdge)
                    .frame(width: 236, height: 236)
                    .offset(y: 6)
                EightPointStar()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFE08A), Theme.C.goldShade], startPoint: .top, endPoint: .bottom))
                    .frame(width: 236, height: 236)
                EightPointStar()
                    .stroke(Color(hex: 0xFFF1C2), lineWidth: 2)
                    .frame(width: 206, height: 206)
                    .rotationEffect(.degrees(spin ? 45 : 0))
                Circle()
                    .fill(Theme.C.button)
                    .frame(width: 150, height: 150)
                    .overlay(Circle().stroke(Theme.C.buttonEdge, lineWidth: 4))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                Text("كلمات")
                    .font(Theme.arabic(46, .bold))
                    .foregroundStyle(.white)
                    .offset(y: -4)
            }
            Text("كلمات متقاطعة بنكهة خليجية")
                .font(Theme.arabic(18, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.S.lg).padding(.vertical, 6)
                .background(Theme.C.coinPill.opacity(0.55), in: Capsule())
        }
        .onAppear { withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { spin = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("كلمات — كلمات متقاطعة بنكهة خليجية")
    }
}

/// Eight-point star (two squares rotated 45°), as one outline.
struct EightPointStar: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        let inner = outer * 0.80
        for i in 0..<16 {
            let a = CGFloat(i) * .pi / 8 - .pi / 2
            let rad = i % 2 == 0 ? outer : inner
            let pt = CGPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}
