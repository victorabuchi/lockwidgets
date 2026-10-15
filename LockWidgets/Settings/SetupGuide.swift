import CoreLocation
import ServiceManagement
import SwiftUI

/// First-run introduction: welcome, pick a few widgets, then learn how to see them.
struct SetupGuide: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow

    @State private var step = 0
    @State private var chosen: Set<WidgetKind> = [.clock, .weather, .calendar, .nowPlaying]

    private let steps = ["Welcome", "Widgets", "Finish"]
    private static let choices: [(WidgetKind, String)] = [
        (.weather, "Conditions at a glance"),
        (.clock, "The time, your way"),
        (.calendar, "What's coming up today"),
        (.nowPlaying, "The song that's playing"),
        (.lyrics, "Sing along on the lock screen"),
        (.battery, "Charge and time left"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(alignment: .center, spacing: 40) {
                Group {
                    switch step {
                    case 0: welcome
                    case 1: widgets
                    default: finish
                    }
                }
                .frame(width: 380, alignment: .leading)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 12)), removal: .opacity))
                .id(step)

                VStack(spacing: 10) {
                    LayoutPreview(instances: previewInstances, colors: [Color(red: 0.42, green: 0.3, blue: 0.85), Color(red: 0.1, green: 0.07, blue: 0.3)])
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
                        .animation(.snappy, value: chosen)
                    Text("A first look at your lock screen")
                        .font(.headline)
                    Text("Live widgets with your own data. Rearrange them anytime in Layout Studio.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 48)
            .frame(maxHeight: .infinity)
            footer
        }
        .frame(width: 1080, height: 700)
        .animation(.snappy(duration: 0.3), value: step)
        .onAppear {
            #if DEBUG
            step = UserDefaults.standard.integer(forKey: "setupStep")
            #endif
            DockPolicy.update()
        }
        .onDisappear { DockPolicy.update() }
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 34, height: 34)
                Text("LockWidgets").font(.system(size: 17, weight: .bold))
            }
            .frame(width: 220, alignment: .leading)
            Spacer()
            // Progress reads as one bar split into the three steps; tapping a finished step goes back to it.
            HStack(spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, name in
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 110, height: 5)
                        Text(name)
                            .font(.system(size: 12, weight: index == step ? .bold : .medium))
                            .foregroundStyle(index <= step ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { if index < step { step = index } }
                }
            }
            Spacer()
            Button("Skip Setup") { close(applying: false) }
                .buttonStyle(.link)
                .frame(width: 220, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .controlSize(.large)
            }
            Spacer()
            Text(footnote)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
            Button(primaryTitle) {
                if step < steps.count - 1 { step += 1 } else { close(applying: true) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(step == 1 && chosen.isEmpty)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(.bar)
    }

    private var primaryTitle: String {
        switch step {
        case 0: "Choose My Widgets"
        case 1: "Looks Good"
        default: "Add Widgets & Open Studio"
        }
    }

    private var footnote: String {
        switch step {
        case 0: "Three quick steps."
        case 1: "\(chosen.count) widget\(chosen.count == 1 ? "" : "s") selected"
        default: "Change anything, anytime."
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Your lock screen.\nNow it has something to say.")
                .font(.system(size: 36, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("The forecast before you head out. The song that's playing. What's next on your calendar. All without unlocking your Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                feature("square.grid.2x2", "Choose your first widgets")
                feature("rectangle.3.group", "Arrange them your way")
                feature("lock", "See them whenever you lock")
            }
            Text("LockWidgets collects no data. Weather, lyrics, news and prices come straight from their public sources.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var widgets: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start with your everyday essentials.")
                .font(.system(size: 30, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Pick what you'd like to see. There are many more in Layout Studio.")
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(Self.choices, id: \.0) { kind, detail in
                    let isOn = chosen.contains(kind)
                    Button {
                        if isOn { chosen.remove(kind) } else { chosen.insert(kind) }
                    } label: {
                        HStack(spacing: 12) {
                            WidgetIcon(kind: kind, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(kind.title).font(.headline)
                                Text(detail).font(.callout).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle")
                                .font(.title2)
                                .foregroundStyle(isOn ? Color.accentColor : .secondary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isOn ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isOn ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var finish: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Make yourself at home.")
                .font(.system(size: 34, weight: .bold))
            Text("Your widgets go on the lock screen next. In Layout Studio you can drag them anywhere and change their size and style.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                Text("Then, lock your Mac.").font(.headline)
                HStack(spacing: 8) {
                    KeyCap("⌃")
                    KeyCap("⌘")
                    KeyCap("Q")
                    Text("Control + Command + Q")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                Text("Widgets appear when you lock and disappear when you sign in.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if chosen.contains(.calendar) {
                    permission("calendar", "Calendar", CalendarStore.shared.hasAccess) { CalendarStore.shared.requestAccess() }
                }
                if chosen.contains(.weather) {
                    permission("location", "Location for weather", CLLocationManager().authorizationStatus != .notDetermined) {
                        WeatherStore.shared.refresh()
                    }
                }
                LaunchAtLoginRow()
            }
        }
    }

    // MARK: Pieces

    private func feature(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.headline)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
        }
    }

    private func permission(_ symbol: String, _ title: String, _ done: Bool, _ ask: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Allow", action: ask)
            }
        }
    }

    private var chosenPreset: [WidgetInstance] {
        let slots: [(WidgetKind, String, CGFloat, CGFloat)] = [
            (.clock, "digital", 56, 250), (.weather, "hourly", 56, 430), (.calendar, "upNext", 56, 610),
            (.nowPlaying, "player", 1112, 250), (.lyrics, "lyrics", 1112, 430), (.battery, "bar", 1112, 610),
        ]
        return slots.filter { chosen.contains($0.0) }.map { LayoutPreset.place($0.0, $0.1, .medium, x: $0.2, y: $0.3) }
    }

    private var previewInstances: [WidgetInstance] {
        step == 0 ? LayoutPreset.starter.instances : chosenPreset
    }

    private func close(applying: Bool) {
        if applying {
            LayoutStore.shared.apply(LayoutPreset(id: "setup", name: "Setup", tagline: "", colors: [], instances: chosenPreset))
            SettingsRouter.shared.page = .layoutStudio
            openWindow(id: "settings")
        }
        UserDefaults.standard.set(true, forKey: SettingsKey.hasLaunched)
        dismissWindow(id: "setup")
    }
}

private struct KeyCap: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.system(size: 18, weight: .medium))
            .frame(width: 44, height: 40)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.background))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.quaternary, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 0, y: 2)
    }
}

struct LaunchAtLoginRow: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle(isOn: $enabled) {
            Label("Launch at login", systemImage: "power")
        }
        .onChange(of: enabled) { _, value in
            do {
                if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSSound.beep()
            }
            enabled = SMAppService.mainApp.status == .enabled
        }
    }
}

/// Shows LockWidgets in the Dock only while one of its windows is open.
enum DockPolicy {
    static func update() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let hasWindow = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
            NSApp.setActivationPolicy(hasWindow ? .regular : .accessory)
            if hasWindow { bringWindowsForward() }
        }
    }

    /// Puts LockWidgets' windows in front of the app the user was in. macOS no longer lets an app simply
    /// activate itself, so the windows are ordered to the front directly as well.
    static func bringWindowsForward() {
        NSApp.activate()
        for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled) {
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
