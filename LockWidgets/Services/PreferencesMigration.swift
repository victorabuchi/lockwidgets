import Foundation

/// LockWidgets used to run in the App Sandbox, which kept its settings inside its container.
/// Without the sandbox they live in the normal preferences, so copy them across once.
enum PreferencesMigration {
    private static let doneKey = "migratedFromSandbox"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey), let bundleID = Bundle.main.bundleIdentifier else { return }
        defaults.set(true, forKey: doneKey)

        let container = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(bundleID)/Data/Library/Preferences/\(bundleID).plist")
        guard let old = NSDictionary(contentsOf: container) as? [String: Any] else { return }
        for (key, value) in old where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }
}
