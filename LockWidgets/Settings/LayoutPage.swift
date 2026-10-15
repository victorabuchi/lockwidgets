import SwiftUI

struct LayoutPage: View {
    @AppStorage(SettingsKey.widgetOrder) private var order = WidgetKind.defaultOrder
    @AppStorage(SettingsKey.hiddenWidgets) private var hidden = ""
    @AppStorage(SettingsKey.position) private var position = BoardPosition.leading
    @AppStorage(SettingsKey.scale) private var scale = 1.0
    @AppStorage(SettingsKey.spacing) private var spacing = Theme.spacing

    var body: some View {
        Form {
            Section {
                PageHeader(title: "Layout", subtitle: "Choose where widgets sit and in what order.")
                LayoutCanvas()
                    .padding(.vertical, 4)
            }

            Section {
                LabeledContent {
                    PositionPad(position: $position)
                } label: {
                    Text("Position")
                    Text("The centre is kept clear for the system clock and login.")
                }
                LabeledContent("Size") {
                    SliderValue(value: $scale, range: 0.7 ... 1.5, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                }
                LabeledContent("Spacing") {
                    SliderValue(value: $spacing, range: 4 ... 32, step: 1) { "\(Int($0)) pt" }
                }
            }

            Section {
                let kinds = WidgetKind.ordered(order)
                ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                    HStack(spacing: 10) {
                        Image(systemName: kind.symbol)
                            .symbolVariant(.fill)
                            .foregroundStyle(kind.color)
                            .frame(width: 22)
                        Toggle(kind.title, isOn: kind.visibility($hidden))
                            .toggleStyle(.checkbox)
                        Spacer()
                        Button { move(kind, by: -1) } label: { Image(systemName: "chevron.up") }
                            .disabled(index == 0)
                        Button { move(kind, by: 1) } label: { Image(systemName: "chevron.down") }
                            .disabled(index == kinds.count - 1)
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                Text("Widgets")
            } footer: {
                Text("Widgets stack from top to bottom in this order.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func move(_ kind: WidgetKind, by offset: Int) {
        var kinds = WidgetKind.ordered(order)
        guard let from = kinds.firstIndex(of: kind), kinds.indices.contains(from + offset) else { return }
        kinds.swapAt(from, from + offset)
        order = kinds.map(\.rawValue).joined(separator: ",")
    }
}

/// The real widget board rendered at screen size and scaled down onto a mock lock screen.
private struct LayoutCanvas: View {
    var body: some View {
        let screen = NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982)
        GeometryReader { proxy in
            let factor = proxy.size.width / screen.width
            ZStack(alignment: .topLeading) {
                LockScreenBackdrop()
                systemChrome
                    .frame(width: screen.width, height: screen.height)
                    .scaleEffect(factor, anchor: .topLeading)
                WidgetBoard()
                    .environment(\.isWidgetPreview, true)
                    .frame(width: screen.width, height: screen.height)
                    .scaleEffect(factor, anchor: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .aspectRatio(screen.width / screen.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .allowsHitTesting(false)
    }

    /// Faint stand-ins for the system clock and login, so it is clear what the widgets must avoid.
    private var systemChrome: some View {
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
        .foregroundStyle(.white.opacity(0.35))
    }
}

/// 3×3 grid of the screen; the middle column is reserved for system UI.
private struct PositionPad: View {
    @Binding var position: BoardPosition

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(0 ..< 3) { row in
                GridRow {
                    cell(BoardPosition.allCases.first { $0.row == row && $0.isLeading }!)
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: 34, height: 22)
                    cell(BoardPosition.allCases.first { $0.row == row && !$0.isLeading }!)
                }
            }
        }
    }

    private func cell(_ value: BoardPosition) -> some View {
        Button { position = value } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(position == value ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
                .frame(width: 34, height: 22)
        }
        .buttonStyle(.plain)
        .help(value.title)
    }
}

struct SliderValue: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: (Double) -> String

    var body: some View {
        HStack {
            Slider(value: $value, in: range, step: step)
                .frame(minWidth: 160)
            Text(label(value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}
