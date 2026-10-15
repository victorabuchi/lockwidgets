import AppKit

/// Temporary: records each mouse click the app receives, to find where clicks are being lost.
/// Writes to ~/Library/Logs/LockWidgets-clicks.log.
enum ClickDiagnostics {
    private static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/LockWidgets-clicks.log")
    private static var monitors: [Any] = []

    static func start() {
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        write("started")
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp], handler: { event in
            let window = event.window
            write("local \(event.type == .leftMouseDown ? "down" : "up") at \(NSEvent.mouseLocation) window=\(window.map { "\(type(of: $0)) '\($0.title)' key=\($0.isKeyWindow)" } ?? "none") active=\(NSApp.isActive) policy=\(NSApp.activationPolicy().rawValue)")
            return event
        }) { monitors.append(local) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { _ in
            write("global down at \(NSEvent.mouseLocation) (went to another app)")
        }) { monitors.append(global) }
    }

    private static func write(_ line: String) {
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        handle.write("\(Date()) \(line)\n".data(using: .utf8)!)
        try? handle.close()
    }
}
