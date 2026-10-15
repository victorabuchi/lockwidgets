import AppKit
import SkyLightWindow
import SwiftUI

final class OverlayManager: ObservableObject {
    @Published private(set) var isShowing = false

    private var controllers: [NSWindowController] = []

    init() {
        CalendarStore.shared.requestAccess()
        _ = LyricsStore.shared

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.refreshData()
            self?.show()
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.hide()
        }
    }

    func show() {
        hide()
        for screen in NSScreen.screens {
            let controller = SkyLightOperator.shared.delegateView(AnyView(WidgetBoard()), toScreen: screen)
            // Full-screen overlay at the top level: let clicks pass through or the Mac becomes unusable.
            controller.window?.ignoresMouseEvents = true
            controllers.append(controller)
        }
        isShowing = true
    }

    func hide() {
        controllers.forEach { $0.close() }
        controllers.removeAll()
        isShowing = false
    }

    func toggle() {
        isShowing ? hide() : show()
    }

    func refreshData() {
        BatteryMonitor.shared.refresh()
        CalendarStore.shared.reload()
        WeatherStore.shared.refresh()
        NowPlayingStore.shared.poll()
    }
}
