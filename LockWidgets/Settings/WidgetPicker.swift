import SwiftUI

/// Sheet for choosing a widget, its style and its size, with live previews.
struct WidgetPicker: View {
    let add: (WidgetKind, String, WidgetSize) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: WidgetKind? = .clock
    @State private var search = ""
    @State private var lastAdded: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Divider()
                gallery
            }
            Divider()
            HStack {
                Label(lastAdded.map { "Added \($0)" } ?? "Double-click a preview or use + to add it", systemImage: lastAdded == nil ? "hand.point.up.left" : "checkmark.circle.fill")
                    .foregroundStyle(lastAdded == nil ? Color.secondary : Color.green)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(14)
        }
        .frame(width: 1000, height: 680)
    }

    private var matches: [WidgetKind] {
        let term = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return WidgetKind.allCases }
        return WidgetKind.allCases.filter {
            $0.title.lowercased().contains(term) || $0.summary.lowercased().contains(term)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            TextField("Search Widgets", text: $search)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .padding(12)
            List(selection: $kind) {
                ForEach(WidgetCategory.allCases, id: \.self) { category in
                    let kinds = matches.filter { $0.category == category }
                    if !kinds.isEmpty {
                        Section(category.rawValue) {
                            ForEach(kinds) { kind in
                                Label {
                                    Text(kind.title)
                                } icon: {
                                    WidgetIcon(kind: kind, size: 26)
                                }
                                .padding(.vertical, 3)
                                .tag(kind)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 250)
    }

    private var gallery: some View {
        ZStack {
            LockScreenBackdrop().opacity(0.9)
            if let kind {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.title)
                                .font(.system(size: 24, weight: .bold))
                            Text(kind.summary)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        ForEach(kind.styles) { style in
                            VStack(alignment: .leading, spacing: 12) {
                                FlowLayout(spacing: 22) {
                                    ForEach(style.sizes) { size in
                                        variant(kind, style, size)
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(kind)
            }
        }
        .foregroundStyle(.white)
    }

    private func variant(_ kind: WidgetKind, _ style: WidgetStyle, _ size: WidgetSize) -> some View {
        let box = size == .large ? CGSize(width: 240, height: 240) : CGSize(width: 500, height: 120)
        return VStack(spacing: 8) {
            FittedWidget(instance: kind.sample(style: style.id, size: size), box: box)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                .overlay(alignment: .topTrailing) {
                    Button {
                        insert(kind, style, size)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 26, height: 26)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: 10, y: -10)
                    .help("Add to your lock screen")
                }
                .onTapGesture(count: 2) { insert(kind, style, size) }
            VStack(spacing: 2) {
                Text("\(style.name) · \(size.title)")
                    .font(.system(size: 13, weight: .semibold))
                Text(style.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func insert(_ kind: WidgetKind, _ style: WidgetStyle, _ size: WidgetSize) {
        add(kind, style.id, size)
        withAnimation { lastAdded = "\(kind.title) · \(size.title)" }
    }
}

/// Lays children out left to right, wrapping onto new rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
