import Foundation
import RecallCore

/// Local-only storage (Recall-UX.md §9.1): one JSON file in Application Support,
/// written atomically and protected by the device passcode until first unlock.
nonisolated struct Persistence: Sendable {
    let directory: URL

    enum LoadResult {
        case missing
        case loaded(RecallData)
        /// The file couldn't be decoded; it was moved aside rather than overwritten.
        case unreadable(movedTo: URL)
    }

    var fileURL: URL { directory.appendingPathComponent("recall.json") }
    var photosDirectory: URL { directory.appendingPathComponent("Photos", isDirectory: true) }

    static func live() -> Persistence {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return Persistence(directory: base.appendingPathComponent("Recall", isDirectory: true))
    }

    /// A throwaway location for UI tests.
    static func temporary() -> Persistence {
        Persistence(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("recall-\(UUID().uuidString)", isDirectory: true))
    }

    func load() -> LoadResult {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return .missing }
        do {
            return .loaded(try RecallCodec.decode(try Data(contentsOf: url)))
        } catch {
            let aside = directory.appendingPathComponent("recall-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: aside)
            return .unreadable(movedTo: aside)
        }
    }

    static func write(_ data: RecallData, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let bytes = try RecallCodec.encode(data)
            try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("Recall: save failed — \(error)")
        }
    }

    /// Stores a photo attached from the live screen; returns its file name.
    func savePhoto(_ jpeg: Data) -> String? {
        let name = "\(UUID().uuidString).jpg"
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            try jpeg.write(to: photosDirectory.appendingPathComponent(name),
                           options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return name
        } catch {
            return nil
        }
    }

    func photoURL(_ name: String) -> URL {
        photosDirectory.appendingPathComponent(name)
    }

    /// The Export JSON payload, written where ShareLink can hand it to Files / AirDrop.
    func writeExport(_ entries: [LogEntry], day: Day) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recall-export-\(day.key).json")
        do {
            try RecallCodec.exportJSON(entries).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
