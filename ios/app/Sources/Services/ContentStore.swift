import Foundation

/// Loads every pack JSON bundled under Resources/Packs.
enum ContentStore {
    static func loadPacks(bundle: Bundle = .main) -> [Pack] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Packs")
            ?? bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let decoder = JSONDecoder()
        return urls.compactMap { try? decoder.decode(Pack.self, from: Data(contentsOf: $0)) }
            .sorted { $0.order < $1.order }
    }
}
