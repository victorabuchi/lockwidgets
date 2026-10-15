import SwiftUI

/// Full-screen layer with every placed widget at its saved position.
struct WidgetBoard: View {
    @ObservedObject private var layout = LayoutStore.shared
    @AppStorage(SettingsKey.scale) private var scale = 1.0

    var body: some View {
        GeometryReader { proxy in
            ForEach(layout.instances) { instance in
                WidgetView(instance: instance)
                    .scaleEffect(scale)
                    .position(x: instance.center.x * proxy.size.width, y: instance.center.y * proxy.size.height)
            }
        }
    }
}
