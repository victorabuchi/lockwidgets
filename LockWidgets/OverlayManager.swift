import AppKit
import SkyLightWindow
import SwiftUI

final class OverlayManager: ObservableObject {
    private var controllers: [NSWindowController] = []

    init() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
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
    }

    func hide() {
        controllers.forEach { $0.close() }
        controllers.removeAll()
    }
}
