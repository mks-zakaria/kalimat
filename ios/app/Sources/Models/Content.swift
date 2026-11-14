import Foundation

/// Bundled, read-only content. Mirrors replica/schema.md and tools/generate.py output.
struct Pack: Codable, Identifiable, Hashable {
    let id: String
    let titleAr: String
    let order: Int
    let region: String
    let levels: [Level]

    enum CodingKeys: String, CodingKey {
        case id, order, region, levels
        case titleAr = "title_ar"
    }
}

struct Level: Codable, Identifiable, Hashable {
    let id: String
    let number: Int
    let width: Int
    let height: Int
    let entries: [Entry]
}

enum Direction: String, Codable { case across, down }

struct Entry: Codable, Identifiable, Hashable {
    let id: String
    let answer: String
    let row: Int
    let col: Int
    let dir: Direction
    let clueAr: String
    let image: String?
    let category: String
    let difficulty: Int

    enum CodingKeys: String, CodingKey {
        case id, answer, row, col, dir, image, category, difficulty
        case clueAr = "clue_ar"
    }

    var letters: [String] { answer.map(String.init) }

    /// Cells in reading order. Col 0 is the rightmost column (RTL layout).
    var cells: [CellPos] {
        (0..<answer.count).map { i in
            dir == .across ? CellPos(row: row, col: col + i) : CellPos(row: row + i, col: col)
        }
    }
}

struct CellPos: Hashable, Codable {
    let row: Int
    let col: Int
}
