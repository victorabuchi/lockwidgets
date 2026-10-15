import SwiftUI

struct LayoutGalleryPage: View {
    @State private var pending: LayoutPreset?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Layout Gallery", subtitle: "Find a layout that feels like you, then make it your own in Layout Studio.")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 18) {
                    ForEach(LayoutPreset.gallery) { preset in
                        PresetCard(preset: preset) { pending = preset }
                    }
                }
                Text("Using a layout replaces the widgets on your lock screen. Your sticky note text and settings stay.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .confirmationDialog(
            "Replace your lock screen with \(pending?.name ?? "this layout")?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { preset in
            Button("Use \(preset.name)") {
                LayoutStore.shared.apply(preset)
                SettingsRouter.shared.page = .layoutStudio
            }
        }
    }
}

private struct PresetCard: View {
    let preset: LayoutPreset
    let use: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LayoutPreview(instances: preset.instances, colors: preset.colors)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name).font(.system(size: 17, weight: .bold))
                    Text(preset.tagline).foregroundStyle(.secondary)
                    Text("\(preset.instances.count) widgets")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                Spacer()
                Button("Use Layout", action: use)
                    .buttonStyle(.borderedProminent)
                    .opacity(hovering ? 1 : 0.85)
            }
            .padding(14)
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.quaternary))
        .scaleEffect(hovering ? 1.01 : 1)
        .animation(.snappy(duration: 0.2), value: hovering)
        .onHover { hovering = $0 }
    }
}

/// A miniature lock screen showing a set of widgets where they would sit.
struct LayoutPreview: View {
    let instances: [WidgetInstance]
    let colors: [Color]

    var body: some View {
        let screen = ScreenGeometry.size
        GeometryReader { proxy in
            let factor = proxy.size.width / screen.width
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                SystemChrome()
                    .frame(width: screen.width, height: screen.height)
                    .scaleEffect(factor, anchor: .topLeading)
                ForEach(instances) { instance in
                    let size = instance.size.points
                    WidgetView(instance: instance)
                        .environment(\.isWidgetPreview, true)
                        .scaleEffect(factor)
                        .frame(width: size.width * factor, height: size.height * factor)
                        .position(x: instance.center.x * proxy.size.width, y: instance.center.y * proxy.size.height)
                }
            }
        }
        .aspectRatio(screen.width / screen.height, contentMode: .fit)
        .allowsHitTesting(false)
        .clipped()
    }
}
