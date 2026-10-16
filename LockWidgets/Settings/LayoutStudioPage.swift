import SwiftUI

struct LayoutStudioPage: View {
    @ObservedObject private var layout = LayoutStore.shared
    @State private var selection: UUID?
    @State private var showPicker = false
    @State private var confirmClear = false
    @AppStorage(SettingsKey.studioBackground) private var background = "dark"
    @AppStorage(SettingsKey.scale) private var scale = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(title: "Layout Studio", subtitle: "Drag widgets to place them. Select one to change its size or style.")

                StudioCanvas(selection: $selection, wallpaper: background == "wallpaper")

                HStack(spacing: 10) {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Add Widget", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Spacer()

                    Picker("Background", selection: $background) {
                        Label("Dark", systemImage: "moon.fill").tag("dark")
                        Label("Wallpaper", systemImage: "photo").tag("wallpaper")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                if let id = selection, let instance = layout.instances.first(where: { $0.id == id }) {
                    SelectionInspector(instance: instance) {
                        layout.remove(id)
                        selection = nil
                    }
                } else {
                    Text(layout.instances.isEmpty
                        ? "Your lock screen is empty. Add a widget or pick a layout from the Gallery."
                        : "Select a widget to resize, restyle or remove it.")
                        .foregroundStyle(.secondary)
                }

                Panel {
                    LabeledContent("Widget size") {
                        SliderValue(value: $scale, range: 0.7 ... 1.4, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                    }
                    Divider()
                    LabeledContent("Start over") {
                        Button("Remove All Widgets", role: .destructive) { confirmClear = true }
                            .disabled(layout.instances.isEmpty)
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showPicker) {
            WidgetPicker { kind, style, size in
                selection = layout.add(kind, style: style, size: size)
            }
        }
        #if DEBUG
        .onAppear { if UserDefaults.standard.bool(forKey: "showPicker") { showPicker = true } }
        #endif
        .confirmationDialog("Remove every widget from your lock screen?", isPresented: $confirmClear) {
            Button("Remove All", role: .destructive) {
                layout.removeAll()
                selection = nil
            }
        }
    }
}

/// The lock screen in miniature. Widgets render at full size and are scaled down, so it matches the real thing.
struct StudioCanvas: View {
    @Binding var selection: UUID?
    var wallpaper = false
    var interactive = true

    @ObservedObject private var layout = LayoutStore.shared
    @ObservedObject private var island = IslandModel.shared
    @AppStorage(SettingsKey.scale) private var scale = 1.0
    @AppStorage(SettingsKey.islandEnabled) private var islandEnabled = true
    @State private var wallpaperImage: NSImage?

    var body: some View {
        let screen = ScreenGeometry.size
        GeometryReader { proxy in
            let canvas = proxy.size
            let factor = canvas.width / screen.width
            ZStack(alignment: .topLeading) {
                backdrop
                    .frame(width: canvas.width, height: canvas.height)
                    .contentShape(Rectangle())
                    .onTapGesture { selection = nil }
                SystemChrome()
                    .frame(width: screen.width, height: screen.height)
                    .scaleEffect(factor, anchor: .topLeading)
                    .allowsHitTesting(false)
                // The Dynamic Island at the notch, live, as it shows on the lock screen.
                if island.hasNotch, islandEnabled {
                    IslandView()
                        .frame(width: screen.width, height: 240)
                        .scaleEffect(factor, anchor: .topLeading)
                        .allowsHitTesting(false)
                }
                ForEach(layout.instances) { instance in
                    StudioItem(
                        instance: instance,
                        canvas: canvas,
                        factor: factor * scale,
                        isSelected: selection == instance.id,
                        interactive: interactive,
                        select: { selection = instance.id }
                    )
                }
            }
            .coordinateSpace(name: "canvas")
        }
        .aspectRatio(screen.width / screen.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.quaternary))
        .onAppear(perform: loadWallpaper)
        .onChange(of: wallpaper) { loadWallpaper() }
    }

    @ViewBuilder
    private var backdrop: some View {
        if wallpaper, let wallpaperImage {
            Image(nsImage: wallpaperImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(colors: [Color(white: 0.2), Color(white: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func loadWallpaper() {
        guard wallpaper, wallpaperImage == nil,
              let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen)
        else { return }
        wallpaperImage = NSImage(contentsOf: url)
    }
}

private struct StudioItem: View {
    let instance: WidgetInstance
    let canvas: CGSize
    let factor: CGFloat
    let isSelected: Bool
    let interactive: Bool
    let select: () -> Void

    @GestureState private var drag = CGSize.zero

    var body: some View {
        let size = instance.size.points
        let movedCenter = CGPoint(
            x: instance.center.x + drag.width / canvas.width,
            y: instance.center.y + drag.height / canvas.height
        )
        let overlaps = LayoutStore.overlapsSystemUI(instance, center: movedCenter)

        WidgetView(instance: instance)
            .environment(\.isWidgetPreview, true)
            .scaleEffect(factor)
            .frame(width: size.width * factor, height: size.height * factor)
            .overlay {
                if isSelected || overlaps {
                    RoundedRectangle(cornerRadius: 24 * factor + 3, style: .continuous)
                        .strokeBorder(overlaps ? Color.orange : Color.accentColor, lineWidth: 2)
                        .padding(-3)
                }
            }
            .contentShape(Rectangle())
            .position(x: instance.center.x * canvas.width + drag.width, y: instance.center.y * canvas.height + drag.height)
            .gesture(interactive ? dragGesture : nil)
            .onTapGesture { if interactive { select() } }
            .animation(.snappy(duration: 0.2), value: isSelected)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("canvas"))
            .updating($drag) { value, state, _ in state = value.translation }
            .onChanged { _ in if !isSelected { select() } }
            .onEnded { value in
                LayoutStore.shared.move(
                    instance.id,
                    by: CGSize(width: value.translation.width / canvas.width, height: value.translation.height / canvas.height)
                )
            }
    }
}

/// Faint stand-ins for the system clock and login, so it is clear what widgets should avoid.
struct SystemChrome: View {
    var body: some View {
        VStack {
            VStack(spacing: 0) {
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month()))
                    .font(.system(size: 26, weight: .semibold))
                Text(Date.now.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 120, weight: .bold, design: .rounded))
            }
            .padding(.top, 70)
            Spacer()
            VStack(spacing: 10) {
                Circle().frame(width: 64, height: 64)
                Text(NSFullUserName()).font(.system(size: 18, weight: .semibold))
            }
            .padding(.bottom, 90)
        }
        .foregroundStyle(.white.opacity(0.3))
    }
}

/// Controls for the selected widget.
private struct SelectionInspector: View {
    let instance: WidgetInstance
    let remove: () -> Void

    var body: some View {
        let kind = instance.kind
        let style = kind.style(instance.style)
        Panel {
            HStack(spacing: 12) {
                WidgetIcon(kind: kind, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.title).font(.headline)
                    Text("\(style.name) · \(instance.size.title)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Remove", role: .destructive, action: remove)
            }
            Divider()
            if kind.styles.count > 1 {
                LabeledContent("Style") {
                    Picker("Style", selection: binding(\.style)) {
                        ForEach(kind.styles) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            LabeledContent("Size") {
                Picker("Size", selection: binding(\.size)) {
                    ForEach(style.sizes) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            InstanceOptions(instance: instance)
            if LayoutStore.overlapsSystemUI(instance) {
                Label("This widget covers the system clock or login area.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func binding<Value>(_ path: WritableKeyPath<WidgetInstance, Value>) -> Binding<Value> {
        Binding {
            instance[keyPath: path]
        } set: { value in
            LayoutStore.shared.update(instance.id) { item in
                item[keyPath: path] = value
                // Keep the size valid when the style changes.
                let sizes = item.kind.style(item.style).sizes
                if !sizes.contains(item.size) { item.size = sizes[0] }
            }
        }
    }
}

/// Settings stored on a single widget rather than shared by its kind.
struct InstanceOptions: View {
    let instance: WidgetInstance

    var body: some View {
        switch instance.kind {
        case .countdown:
            LabeledContent("Title") {
                TextField("Title", text: config("title"), prompt: Text("New Year"))
                    .labelsHidden()
                    .frame(maxWidth: 260)
            }
            LabeledContent("Counting down to") {
                DatePicker("Date", selection: countdownDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
        case .stickyNote:
            NoteEditor(instance: instance)
        default:
            EmptyView()
        }
    }

    private func config(_ key: String) -> Binding<String> {
        Binding {
            instance.config[key] ?? ""
        } set: { value in
            LayoutStore.shared.update(instance.id) { $0.config[key] = value }
        }
    }

    private var countdownDate: Binding<Date> {
        Binding {
            Countdown.target(instance)
        } set: { date in
            LayoutStore.shared.update(instance.id) { $0.config["date"] = String(date.timeIntervalSince1970) }
        }
    }
}

/// Rounded group used on custom (non-Form) pages.
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WidgetIcon: View {
    let kind: WidgetKind
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: kind.symbol)
            .resizable()
            .symbolVariant(.fill)
            .scaledToFit()
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(width: size * 0.58, height: size * 0.58)
            .frame(width: size, height: size)
            .background(kind.color.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}
