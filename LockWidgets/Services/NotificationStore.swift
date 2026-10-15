import AppKit
import SQLite3

/// Mirrors notifications from every app by reading the database where macOS records delivered notifications.
/// Apple offers no API for other apps' notifications; this needs Full Disk Access.
final class NotificationStore: ObservableObject {
    static let shared = NotificationStore()

    struct Item: Equatable, Identifiable {
        let id: Int64
        let bundleID: String
        let title: String
        let subtitle: String
        let body: String
        let date: Date

        var appName: String {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
                .flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? $0.deletingPathExtension().lastPathComponent }
                ?? bundleID
        }
    }

    enum Status: Equatable {
        case needsAccess
        case connected
        case failed(String)
    }

    @Published private(set) var status = Status.needsAccess
    /// Called on the main queue for each new notification.
    var onNotification: ((Item) -> Void)?

    private var lastID: Int64?
    private var timer: Timer?
    private let queue = DispatchQueue(label: "LockWidgets.Notifications")

    private static var databaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db")
    }

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }

    private func poll() {
        queue.async { [weak self] in
            guard let self else { return }
            let result = Self.read(after: lastID)
            DispatchQueue.main.async {
                switch result {
                case let .success((items, maxID)):
                    if self.status != .connected { self.status = .connected }
                    // The first read only notes where the history ends, so old notifications aren't replayed.
                    if self.lastID != nil { items.forEach { self.onNotification?($0) } }
                    self.lastID = max(self.lastID ?? 0, maxID)
                case let .failure(error):
                    if self.status != error.status { self.status = error.status }
                }
            }
        }
    }

    private struct ReadError: Error {
        let status: Status
    }

    private static func read(after lastID: Int64?) -> Result<([Item], Int64), ReadError> {
        let path = databaseURL.path
        guard FileManager.default.isReadableFile(atPath: path) else { return .failure(ReadError(status: .needsAccess)) }

        var database: OpaquePointer?
        guard sqlite3_open_v2("file:\(path)?mode=ro", &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "can't open"
            sqlite3_close(database)
            return .failure(ReadError(status: message.contains("authorization") ? .needsAccess : .failed(message)))
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT r.rec_id, a.identifier, r.data FROM record r
        JOIN app a ON a.app_id = r.app_id
        WHERE r.rec_id > ? ORDER BY r.rec_id
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            return .failure(ReadError(status: .failed(String(cString: sqlite3_errmsg(database)))))
        }
        defer { sqlite3_finalize(statement) }
        // On the first read only the newest id matters.
        sqlite3_bind_int64(statement, 1, lastID ?? Int64.max - 1)

        var items: [Item] = []
        var maxID = lastID ?? 0
        if lastID == nil {
            var newest: OpaquePointer?
            if sqlite3_prepare_v2(database, "SELECT IFNULL(MAX(rec_id), 0) FROM record", -1, &newest, nil) == SQLITE_OK,
               sqlite3_step(newest) == SQLITE_ROW
            {
                maxID = sqlite3_column_int64(newest, 0)
            }
            sqlite3_finalize(newest)
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            maxID = max(maxID, id)
            let bundleID = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            let length = Int(sqlite3_column_bytes(statement, 2))
            guard let bytes = sqlite3_column_blob(statement, 2), length > 0,
                  let plist = try? PropertyListSerialization.propertyList(from: Data(bytes: bytes, count: length), format: nil) as? [String: Any],
                  let request = plist["req"] as? [String: Any]
            else { continue }
            let title = request["titl"] as? String ?? ""
            let subtitle = request["subt"] as? String ?? ""
            let body = request["body"] as? String ?? ""
            guard !(title.isEmpty && body.isEmpty), bundleID != Bundle.main.bundleIdentifier else { continue }
            let date = (plist["date"] as? Double).map { Date(timeIntervalSinceReferenceDate: $0) } ?? .now
            items.append(Item(id: id, bundleID: bundleID, title: title, subtitle: subtitle, body: body, date: date))
        }
        return .success((items, maxID))
    }
}
