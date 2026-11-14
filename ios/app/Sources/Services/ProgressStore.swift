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
    var processedTransactions: [String] = []
    var settings = Settings()

    init() {}

    /// Missing keys fall back to defaults, so adding a field never wipes a player's progress.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        currentLevelId = try c.decodeIfPresent(String.self, forKey: .currentLevelId)
        levels = try c.decodeIfPresent([String: LevelProgress].self, forKey: .levels) ?? [:]
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? ProgressStore.startingCoins
        processedTransactions = try c.decodeIfPresent([String].self, forKey: .processedTransactions) ?? []
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
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
