import AppKit
import Sparkle

/// Keeps Notchlight up to date with Sparkle. Each release on GitHub publishes a signed appcast, so
/// updates reach everyone who downloaded the app, not only people who come back to GitHub.
final class Updater: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    static let shared = Updater()

    /// A newer version found by a background check, waiting in the menu until the user looks at it.
    @Published private(set) var availableVersion: String?

    private lazy var controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            controller.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    func start() {
        _ = controller
    }

    func checkForUpdates() {
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    // MARK: Gentle reminders

    // Notchlight lives in the menu bar and is rarely in front, so a background check doesn't pop an
    // alert over whatever the user is doing; it marks the update in the menu instead.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state _: SPUUserUpdateState) {
        if !handleShowingUpdate { availableVersion = update.displayVersionString }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate _: SUAppcastItem) {
        availableVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
    }
}
