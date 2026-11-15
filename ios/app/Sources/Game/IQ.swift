import Foundation

/// "IQ" score — a game score, not a psychometric test (the app says so wherever it is shown).
///
/// Per level: how fast the player solved it compared with an expected time for that level
/// (number of words, their length and difficulty, the mode), minus a little per hint.
/// On pace = 100, twice as fast = 120, twice as slow = 80, kept within 70...160.
///
/// Overall: each first completion moves the player's IQ toward the level score. Early levels
/// move it a lot (the first one sets it), later ones less (never below 15 %), so it settles
/// but still follows real improvement. Replays never count: the answers are already known.
enum IQ {
    static let floor = 70.0, ceiling = 160.0
    static let pointsPerDoubling = 20.0      // twice as fast = +20
    static let hintPenalty = 5.0
    static let minWeight = 0.15

    /// Seconds an average player needs for this level. Tune these with real play data.
    static func expectedSeconds(_ level: Level, mode: GameMode, gridSize: Int = 8) -> Double {
        let perWord: (Entry) -> Double = { e in
            let n = Double(ArabicText.normalise(e.answer).count)
            let difficulty = [1: 1.0, 2: 1.3, 3: 1.6][e.difficulty] ?? 1.3
            switch mode {
            case .crossword:  return (8 + 1.5 * n) * difficulty         // read clue, think, type
            case .wordSearch: return (9 + 0.8 * n) * difficulty         // read clue, scan, draw
            }
        }
        let base = level.entries.reduce(0) { $0 + perWord($1) }
        return mode == .wordSearch ? base * Double(gridSize) / 8 : base
    }

    static func levelScore(expected: Double, actual: Double, hints: Int) -> Int {
        let t = max(actual, 1)
        let raw = 100 + pointsPerDoubling * log2(expected / t) - hintPenalty * Double(hints)
        return Int(min(ceiling, max(floor, raw)).rounded())
    }

    /// New overall IQ after a level, from the old one and how many levels it is based on.
    static func updated(global: Double?, count: Int, with level: Int) -> Double {
        guard let global, count > 0 else { return Double(level) }
        let weight = max(minWeight, 1 / Double(count + 1))
        return global + weight * (Double(level) - global)
    }
}

/// What the level-complete screen shows.
struct IQResult: Equatable {
    let level: Int          // this level's score
    let before: Int?        // overall IQ before (nil on the very first level)
    let after: Int          // overall IQ now
    let counted: Bool       // false for a replay
}

/// Active solving time for one level: pauses in the background and while a full-screen ad
/// is on screen, so neither counts against the player.
@MainActor
final class SolveClock {
    private var startedAt: Date?
    private var pausedByAd = false
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    var onPause: ((TimeInterval) -> Void)?

    init() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .fullScreenAdWillPresent, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.startedAt != nil else { return }
                self.pause(); self.pausedByAd = true
            }
        })
        observers.append(nc.addObserver(forName: .fullScreenAdDidDismiss, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.pausedByAd else { return }
                self.pausedByAd = false; self.resume()
            }
        })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    var isRunning: Bool { startedAt != nil }

    func resume() { if startedAt == nil { startedAt = Date() } }

    /// Stops the clock and reports the seconds since it was last resumed.
    func pause() {
        guard let s = startedAt else { return }
        startedAt = nil
        onPause?(Date().timeIntervalSince(s))
    }
}

extension Notification.Name {
    static let fullScreenAdWillPresent = Notification.Name("fullScreenAdWillPresent")
    static let fullScreenAdDidDismiss = Notification.Name("fullScreenAdDidDismiss")
}
