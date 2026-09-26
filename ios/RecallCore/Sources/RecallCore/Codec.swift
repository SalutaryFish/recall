import Foundation

/// JSON on disk and for export: ISO 8601 dates, stable key order.
public enum RecallCodec {
    public static func encode(_ snapshot: RecallData) throws -> Data {
        try encoder(pretty: false).encode(snapshot)
    }

    public static func decode(_ data: Data) throws -> RecallData {
        try decoder().decode(RecallData.self, from: data)
    }

    /// The "Export JSON" payload: `{ "entries": [...] }`, human-readable.
    public static func exportJSON(_ entries: [LogEntry]) throws -> Data {
        struct Export: Encodable { let entries: [LogEntry] }
        return try encoder(pretty: true).encode(Export(entries: entries.sorted { $0.start < $1.start }))
    }

    static func encoder(pretty: Bool) -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(ISO8601.string(from: date))
        }
        e.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            guard let date = ISO8601.date(from: s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Not an ISO 8601 date: \(s)")
            }
            return date
        }
        return d
    }
}
