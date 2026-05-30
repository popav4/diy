//
//  ExternalFileKindCatalog.swift
//  DiskInventoryY
//
//  Loads extension -> human-readable file kind mappings from bundled JSON.
//

import Foundation

final class ExternalFileKindCatalog {
    static let shared = ExternalFileKindCatalog()

    private struct Catalog: Decodable {
        let extensions: [String: Entry]
    }

    private struct Entry: Decodable {
        let name: String
    }

    private let extensionsToName: [String: String]

    private init() {
        guard
            let url = Bundle.main.url(forResource: "ExternalFileKinds", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(Catalog.self, from: data)
        else {
            extensionsToName = [:]
            return
        }

        extensionsToName = decoded.extensions
            .mapValues { $0.name }
    }

    func kindName(forExtension ext: String) -> String? {
        extensionsToName[ext.lowercased()]
    }
}
