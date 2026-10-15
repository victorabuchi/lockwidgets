import SwiftUI

enum SettingsPage: Hashable {
    case general, layout, appearance, about
    case widget(WidgetKind)

    #if DEBUG
    /// `-settingsPage layout` (or a widget name) opens settings on that page, for screenshots.
    static var launchPage: SettingsPage? {
        guard let name = UserDefaults.standard.string(forKey: "settingsPage") else { return nil }
        if let kind = WidgetKind(rawValue: name) { return .widget(kind) }
        return ["general": .general, "layout": .layout, "appearance": .appearance, "about": .about][name]
    }
    #endif
}

struct SettingsWindow: View {
    @ObservedObject var overlay: OverlayManager
    @State private var page: SettingsPage? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                SidebarRow(title: "General", symbol: "gearshape.fill", color: .gray)
                    .tag(SettingsPage.general)

                Section("Lock Screen") {
                    SidebarRow(title: "Layout", symbol: "rectangle.3.group.fill", color: .blue)
                        .tag(SettingsPage.layout)
                    SidebarRow(title: "Appearance", symbol: "paintpalette.fill", color: .teal)
                        .tag(SettingsPage.appearance)
                }

                Section("Widgets") {
                    ForEach(WidgetKind.allCases) { kind in
                        SidebarRow(title: kind.title, symbol: kind.symbol, color: kind.color)
                            .tag(SettingsPage.widget(kind))
                    }
                }

                Section {
                    SidebarRow(title: "About", symbol: "info.circle.fill", color: .indigo)
                        .tag(SettingsPage.about)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            switch page ?? .general {
            case .general: GeneralPage(overlay: overlay)
            case .layout: LayoutPage()
            case .appearance: AppearancePage()
            case .about: AboutPage()
            case let .widget(kind): WidgetPage(kind: kind)
            }
        }
        .frame(minWidth: 820, minHeight: 600)
        .onAppear {
            #if DEBUG
            if let launchPage = SettingsPage.launchPage { page = launchPage }
            #endif
            // Show in the Dock and app switcher only while settings are open.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            // Fit every symbol into the same inner box so wide ones (battery) stay centred.
            Image(systemName: symbol)
                .resizable()
                .symbolVariant(.fill)
                .scaledToFit()
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 13, height: 13)
                .frame(width: 22, height: 22)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.vertical, 2)
    }
}

// MARK: Shared page pieces

/// Lock-screen-like backdrop for live widget previews.
struct PreviewStage<Content: View>: View {
    var height: CGFloat = 280
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LockScreenBackdrop()
            content
                .environment(\.isWidgetPreview, true)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct LockScreenBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.27, blue: 0.75), Color(red: 0.12, green: 0.1, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(red: 0.75, green: 0.55, blue: 1).opacity(0.55), .clear],
                center: .init(x: 0.2, y: 0.3),
                startRadius: 0,
                endRadius: 420
            )
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
