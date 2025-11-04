import Foundation
import SQLite3

public struct CursorCredentialExtractor {
    public enum ExtractionError: Error {
        case databaseNotFound
        case databaseOpenFailed
        case tokenNotFound
    }

    private let databaseURL: URL

    public init(databaseURL: URL = CursorCredentialExtractor.defaultDatabaseURL()) {
        self.databaseURL = databaseURL
    }

    public static func defaultDatabaseURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("Cursor")
            .appendingPathComponent("User")
            .appendingPathComponent("globalStorage")
            .appendingPathComponent("state.vscdb")
    }

    public func extractSessionCookie() throws -> String {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw ExtractionError.databaseNotFound
        }
        var db: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK, let db else {
            throw ExtractionError.databaseOpenFailed
        }
        defer { sqlite3_close(db) }

        let query = "SELECT value FROM ItemTable WHERE key LIKE '%auth.session'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw ExtractionError.tokenNotFound
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let blob = sqlite3_column_blob(statement, 0) {
                let size = sqlite3_column_bytes(statement, 0)
                let data = Data(bytes: blob, count: Int(size))
                if let token = parseSessionCookie(from: data) {
                    return token
                }
            }
        }
        throw ExtractionError.tokenNotFound
    }

    private func parseSessionCookie(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let session = json["session"] as? [String: Any],
           let cookie = session["cookie"] as? String {
            return cookie
        }
        if let value = json["value"] as? String {
            return value
        }
        return nil
    }
}
