import AppKit
import Combine
import SwiftUI

/// A borderless panel over the notch that hosts the island and only takes clicks inside the island itself.
final class IslandController {
    static let shared = IslandController()

    private var panel: NSPanel?
    private var monitors: [Any] = []
    private var pointerTimer: Timer?
    private var lastPointer = NSPoint(x: -1, y: -1)
    private var subscriptions: Set<AnyCancellable> = []
    private var collapseWork: DispatchWorkItem?
    private var expandWork: DispatchWorkItem?
    private let canvas = CGSize(width: 760, height: 320)

    private var enabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.islandEnabled) as? Bool ?? true
    }

    func start() {
        let distributed = DistributedNotificationCenter.default()
        // While locked, the lock screen layer draws its own copy of the island (see OverlayManager);
        // this interactive one steps aside and comes back on unlock.
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            IslandModel.shared.isExpanded = false
            self?.panel?.orderOut(nil)
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.update()
        }
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.position() }
            .store(in: &subscriptions)

        // Follow the pointer by sampling its position rather than subscribing to every mouse movement:
        // global and local mouse-moved monitors stop clicks reaching LockWidgets' own windows on this macOS.
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            self?.trackMouse()
        }
        timer.tolerance = 0.01
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer

        // Open the island on mouse-down at the AppKit level, so the first click always counts
        // even though LockWidgets is in the background. Clicks inside the open card go to its buttons.
        if let clicks = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] event in
            guard let self, event.window === panel else { return event }
            return handleClick(event) ? nil : event
        }) {
            monitors.append(clicks)
        }
        update()
    }

    /// Returns true when the click was used to open the island.
    private func handleClick(_: NSEvent) -> Bool {
        let model = IslandModel.shared
        guard !model.isExpanded else { return false }
        if hoverRect.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation) {
            model.toggleExpanded()
            return true
        }
        return false
    }

    private func update() {
        if enabled {
            if panel == nil { makePanel() }
            position()
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
    }

    private func makePanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: canvas),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar + 8
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.contentView = FirstClickHostingView(rootView: IslandView())
        self.panel = panel
    }

    private func position() {
        guard let panel, let screen = IslandModel.screen else { return }
        let frame = screen.frame
        panel.setFrame(NSRect(x: frame.midX - canvas.width / 2, y: frame.maxY - canvas.height, width: canvas.width, height: canvas.height), display: true)
    }

    /// A rectangle of the given size hanging from the top of the screen, centred on the notch.
    private func rect(_ size: CGSize) -> NSRect {
        guard let screen = IslandModel.screen else { return .zero }
        return NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height, width: size.width, height: size.height)
    }

    /// Where the pointer counts as on the island.
    private var hoverRect: NSRect {
        rect(IslandModel.shared.size)
    }

    private func trackMouse() {
        guard let panel, panel.isVisible else { return }
        let model = IslandModel.shared
        let pointer = NSEvent.mouseLocation
        let inside = hoverRect.insetBy(dx: -4, dy: -4).contains(pointer) && model.primary != nil
        // Nothing to do while the pointer rests elsewhere.
        if pointer == lastPointer, panel.ignoresMouseEvents == !inside { return }
        lastPointer = pointer
        if panel.ignoresMouseEvents != !inside { panel.ignoresMouseEvents = !inside }
        if model.isHovering != inside { model.isHovering = inside }

        // Resting on the island opens it, as macOS keeps clicks in the menu bar strip for itself.
        if inside, !model.isExpanded, model.primary?.canExpand == true {
            if expandWork == nil {
                let work = DispatchWorkItem { [weak self] in
                    model.isExpanded = true
                    self?.expandWork = nil
                }
                expandWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
            }
        } else {
            expandWork?.cancel()
            expandWork = nil
        }

        // Close the full card shortly after the pointer leaves, however much it moves meanwhile.
        if model.isExpanded, !inside {
            if collapseWork == nil {
                let work = DispatchWorkItem { [weak self] in
                    model.isExpanded = false
                    self?.collapseWork = nil
                }
                collapseWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
            }
        } else {
            collapseWork?.cancel()
            collapseWork = nil
        }
    }
}

/// Lets the first click on the island act immediately, without activating LockWidgets first.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
}
