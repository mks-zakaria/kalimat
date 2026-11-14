// Dumps every word-search level exactly as the app builds it (same Swift code), for the website.
// Run by tools/build_site.py; by hand:
// swiftc -O -parse-as-library tools/export_wordsearch.swift Sources/Models/Content.swift Sources/Game/*.swift -o /tmp/wsexport && /tmp/wsexport Resources/Packs out.json
import Foundation

@main
struct WSExport {
    static func main() throws {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
        let packs = try files.map { try JSONDecoder().decode(Pack.self, from: Data(contentsOf: $0)) }
            .sorted { $0.order < $1.order }
        let out: [[String: Any]] = WordSearchContent.packs(from: packs).map { pack in
            [
                "id": pack.id, "title_ar": pack.titleAr, "order": pack.order,
                "levels": pack.levels.map { level -> [String: Any] in
                    let p = WordSearchGenerator.make(level: level)
                    return [
                        "id": level.id, "number": level.number, "size": p.size, "grid": p.grid,
                        "entries": level.entries.map { e -> [String: Any] in
                            let pl = p.placements[e.id]!
                            return ["id": e.id, "answer": e.answer, "clue_ar": e.clueAr, "category": e.category,
                                    "dr": pl.dr, "dc": pl.dc, "cells": pl.cells.map { [$0.row, $0.col] }]
                        },
                    ]
                },
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        print("exported \(out.count) word-search packs")
    }
}
