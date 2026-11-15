import Foundation
import Observation

/// Everything the player has earned, in one small JSON file in Application Support.
/// (iCloud mirroring comes in M3; the file format is already the one in replica/schema.md.)
struct Settings: Codable, Equatable {
    var sound = true
}

struct SaveFile: Codable {
    var version = 1
    var updatedAt = Date()
    var currentLevelId: String?
    var levels: [String: LevelProgress] = [:]
    var coins = ProgressStore.startingCoins
    var settings = Settings()
    var iq: Double?                 // overall IQ score (see Game/IQ.swift)
    var iqLevels = 0                // first completions it is based on
    var reviewAskedVersion: String? // app version the rating prompt was last shown for

    init() {}

    /// Missing keys fall back to defaults, so adding a field never wipes a player's progress.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        currentLevelId = try c.decodeIfPresent(String.self, forKey: .currentLevelId)
        levels = try c.decodeIfPresent([String: LevelProgress].self, forKey: .levels) ?? [:]
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? ProgressStore.startingCoins
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        iq = try c.decodeIfPresent(Double.self, forKey: .iq)
        iqLevels = try c.decodeIfPresent(Int.self, forKey: .iqLevels) ?? 0
        reviewAskedVersion = try c.decodeIfPresent(String.self, forKey: .reviewAskedVersion)
    }
}

@Observable
final class ProgressStore {
    static let startingCoins = 100
    static let revealCost = 20
    static let removeCost = 10

    private(set) var file: SaveFile
    private let url: URL

    init(url: URL = ProgressStore.defaultURL) {
        self.url = url
        if let data = try? Data(contentsOf: url), let f = try? JSONDecoder.iso.decode(SaveFile.self, from: data) {
            file = f
        } else {
            file = SaveFile()
        }
    }

    static var defaultURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }

    // MARK: levels

    func progress(for levelId: String) -> LevelProgress? { file.levels[levelId] }
    func stars(for levelId: String) -> Int { file.levels[levelId]?.stars ?? 0 }
    func isComplete(_ levelId: String) -> Bool { file.levels[levelId]?.completedAt != nil }

    func update(_ levelId: String, _ p: LevelProgress) {
        var p = p
        // keep the first completion date and the best stars
        if let old = file.levels[levelId] {
            p.completedAt = old.completedAt ?? p.completedAt
            p.stars = max(old.stars, p.stars)
            p.elapsed = old.elapsed          // engines don't track time; the clock does
            p.iq = old.iq
        }
        file.levels[levelId] = p
        file.currentLevelId = levelId
        persist()
    }

    /// Levels open one after another inside a pack.
    func isUnlocked(_ level: Level, in pack: Pack) -> Bool {
        guard let i = pack.levels.firstIndex(of: level) else { return false }
        return i == 0 || isComplete(pack.levels[i - 1].id)
    }

    /// A pack opens when the one before it is complete.
    func isUnlocked(_ pack: Pack, in packs: [Pack]) -> Bool {
        guard let i = packs.firstIndex(of: pack) else { return false }
        return i == 0 || packs[i - 1].levels.allSatisfy { isComplete($0.id) }
    }

    func solvedCount(_ pack: Pack) -> Int { pack.levels.filter { isComplete($0.id) }.count }
    func totalStars(_ pack: Pack) -> Int { pack.levels.reduce(0) { $0 + stars(for: $1.id) } }

    // MARK: IQ

    var iq: Int? { file.iq.map { Int($0.rounded()) } }
    var bestLevelIQ: Int? { file.levels.values.compactMap(\.iq).max() }
    /// Score of the most recently finished level that counted.
    var lastLevelIQ: Int? {
        file.levels.values.filter { $0.iq != nil }.max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }?.iq
    }

    /// Adds active solving time to a level that is not finished yet.
    func addTime(_ levelId: String, _ seconds: TimeInterval) {
        guard seconds > 0, seconds < 6 * 3600 else { return }      // ignore clock jumps
        var p = file.levels[levelId] ?? LevelProgress()
        guard p.iq == nil else { return }
        p.elapsed += seconds
        file.levels[levelId] = p
        persist()
    }

    /// Scores a finished level and updates the overall IQ — first completion only.
    func recordIQ(_ levelId: String, expected: Double, hints: Int) -> IQResult {
        let before = iq
        guard var p = file.levels[levelId], p.iq == nil else {
            return IQResult(level: file.levels[levelId]?.iq ?? 100, before: before, after: before ?? 100, counted: false)
        }
        let score = IQ.levelScore(expected: expected, actual: p.elapsed, hints: hints)
        p.iq = score
        file.levels[levelId] = p
        file.iq = IQ.updated(global: file.iq, count: file.iqLevels, with: score)
        file.iqLevels += 1
        persist()
        return IQResult(level: score, before: before, after: iq ?? score, counted: true)
    }

    // MARK: rating prompt

    /// Ask for a rating at most once per app version, only after real play: on the 8th,
    /// 30th or 80th finished level. iOS itself also caps it at 3 prompts a year.
    func shouldAskForReview() -> Bool {
        let done = file.levels.values.filter { $0.completedAt != nil }.count
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        guard [8, 30, 80].contains(done), file.reviewAskedVersion != version else { return false }
        file.reviewAskedVersion = version
        persist()
        return true
    }

    // MARK: settings

    var soundOn: Bool {
        get { file.settings.sound }
        set { file.settings.sound = newValue; persist() }
    }

    // MARK: coins

    var coins: Int { file.coins }

    @discardableResult
    func spend(_ n: Int) -> Bool {
        guard file.coins >= n else { return false }
        file.coins -= n
        persist()
        return true
    }

    func earn(_ n: Int) {
        file.coins += n
        persist()
    }

    // MARK: disk

    private func persist() {
        file.updatedAt = Date()
        guard let data = try? JSONEncoder.iso.encode(file) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

extension JSONEncoder {
    static let iso: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
}
extension JSONDecoder {
    static let iso: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
}

#if DEBUG
extension ProgressStore {
    /// Store screenshots only (`-demo`, debug builds): a believable mid-game save — the first
    /// levels of each mode solved, some coins, an IQ based on several levels.
    func seedDemo(packs: [Pack], wsPacks: [Pack]) {
        var f = SaveFile()
        let stars = [3, 3, 2, 3, 3, 2, 3]
        for (i, l) in packs[0].levels.prefix(5).enumerated() {
            var p = LevelProgress(stars: stars[i], completedAt: Date().addingTimeInterval(Double(i - 20) * 3600))
            p.solved = l.entries.map(\.id); p.iq = [112, 121, 109, 118, 124][i]; p.elapsed = 80
            f.levels[l.id] = p
        }
        for (i, l) in wsPacks[0].levels.prefix(3).enumerated() {
            var p = LevelProgress(stars: stars[i + 3], completedAt: Date().addingTimeInterval(Double(i - 10) * 3600))
            p.solved = l.entries.map(\.id); p.iq = [116, 127, 113][i]; p.elapsed = 90
            f.levels[l.id] = p
        }
        f.coins = 240
        f.iq = 118
        f.iqLevels = 8
        file = f
        persist()
    }
}
#endif
