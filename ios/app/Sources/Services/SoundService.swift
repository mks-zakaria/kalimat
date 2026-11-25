import AVFoundation
import UIKit

/// Plays the game's own synthesised sounds (tools/make_sounds.py) with matching haptics.
/// Uses the `.ambient` session: silent when the ringer switch is off, mixes with the
/// player's music, never interrupts audio.
@MainActor
final class SoundService {
    static let shared = SoundService()

    enum Sound: String, CaseIterable {
        case tap, key, undo, wrong, correct, complete, star, hint, erase, coin, open
    }

    var enabled = true

    private var players: [Sound: [AVAudioPlayer]] = [:]
    private var next: [Sound: Int] = [:]
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for s in Sound.allCases {
            guard let url = Bundle.main.url(forResource: s.rawValue, withExtension: "wav") else { continue }
            // a few players per sound so fast typing never cuts the previous key off
            let count = (s == .key || s == .tap || s == .undo) ? 4 : 1
            players[s] = (0..<count).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
        light.prepare()
    }

    func play(_ s: Sound) {
        haptic(for: s)
        guard enabled, let pool = players[s], !pool.isEmpty else { return }
        let i = next[s, default: 0]
        next[s] = (i + 1) % pool.count
        let p = pool[i]
        p.currentTime = 0
        p.play()
    }

    private func haptic(for s: Sound) {
        switch s {
        case .key, .tap, .undo, .open: light.impactOccurred(intensity: 0.6)
        case .wrong: notify.notificationOccurred(.error)
        case .correct, .complete: notify.notificationOccurred(.success)
        case .hint, .erase, .coin, .star: light.impactOccurred()
        }
    }
}
