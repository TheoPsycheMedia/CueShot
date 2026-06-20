import Foundation

struct CaptureHistoryStore {
    private let fileManager: FileManager
    private let applicationSupportURL: URL?
    private let historyLimit = 30

    init(fileManager: FileManager = .default, applicationSupportURL: URL? = nil) {
        self.fileManager = fileManager
        self.applicationSupportURL = applicationSupportURL
    }

    func load() -> [CaptureRecord] {
        guard let data = try? Data(contentsOf: manifestURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CaptureRecord].self, from: data)) ?? []
    }

    func persist(result: CaptureResult) throws -> CaptureRecord {
        try ensureDirectories()

        let relativePath = "PNG/\(result.record.id.uuidString).png"
        let pngURL = historyDirectory.appendingPathComponent(relativePath)
        try result.pngData.write(to: pngURL, options: .atomic)

        let record = result.record.withPNGRelativePath(relativePath)
        var records = load()
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        records = Array(records.prefix(historyLimit))
        try save(records)
        try pruneFiles(keeping: records)
        return record
    }

    func update(_ record: CaptureRecord) throws {
        var records = load()
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            return
        }

        records[index] = record
        try save(records)
    }

    func pngData(for record: CaptureRecord) -> Data? {
        guard let url = pngURL(for: record) else {
            return nil
        }

        return try? Data(contentsOf: url)
    }

    func pngURL(for record: CaptureRecord) -> URL? {
        guard let pngRelativePath = record.pngRelativePath else {
            return nil
        }

        return historyDirectory.appendingPathComponent(pngRelativePath)
    }

    func delete(_ record: CaptureRecord) {
        if let pngURL = pngURL(for: record) {
            try? fileManager.removeItem(at: pngURL)
        }

        let records = load().filter { $0.id != record.id }
        try? save(records)
    }

    func clear() {
        try? fileManager.removeItem(at: historyDirectory)
        try? ensureDirectories()
        try? save([])
    }

    var historyDirectoryURL: URL {
        historyDirectory
    }

    private func save(_ records: [CaptureRecord]) throws {
        try ensureDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: pngDirectory, withIntermediateDirectories: true)
    }

    private func pruneFiles(keeping records: [CaptureRecord]) throws {
        let keptPaths = Set(records.compactMap(\.pngRelativePath))
        let files = (try? fileManager.contentsOfDirectory(at: pngDirectory, includingPropertiesForKeys: nil)) ?? []

        for file in files {
            let relativePath = "PNG/\(file.lastPathComponent)"
            if !keptPaths.contains(relativePath) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private var applicationSupportDirectory: URL {
        if let applicationSupportURL {
            return applicationSupportURL
        }

        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CueShot", isDirectory: true)
    }

    private var historyDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("History", isDirectory: true)
    }

    private var pngDirectory: URL {
        historyDirectory.appendingPathComponent("PNG", isDirectory: true)
    }

    private var manifestURL: URL {
        historyDirectory.appendingPathComponent("captures.json")
    }
}
