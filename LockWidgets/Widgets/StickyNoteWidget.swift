import SwiftUI

enum NoteColor: String, CaseIterable, Identifiable {
    case yellow, pink, green, blue, purple

    var id: String { rawValue }

    var paper: Color {
        switch self {
        case .yellow: Color(red: 1, green: 0.89, blue: 0.5)
        case .pink: Color(red: 1, green: 0.76, blue: 0.82)
        case .green: Color(red: 0.73, green: 0.92, blue: 0.7)
        case .blue: Color(red: 0.7, green: 0.85, blue: 1)
        case .purple: Color(red: 0.84, green: 0.77, blue: 1)
        }
    }
}

struct StickyNoteWidget: View {
    let instance: WidgetInstance

    var body: some View {
        let text = instance.config["text"].flatMap { $0.isEmpty ? nil : $0 } ?? "Write something in Sticky Notes."
        let color = NoteColor(rawValue: instance.config["color"] ?? "") ?? .yellow
        let fontSize: CGFloat = instance.size == .large ? 24 : instance.size == .medium ? 19 : 16

        if instance.style == "glass" {
            WidgetCard(size: instance.size) {
                note(text, size: fontSize)
            }
        } else {
            note(text, size: fontSize)
                .padding(18)
                .frame(width: instance.size.points.width, height: instance.size.points.height, alignment: .topLeading)
                .foregroundStyle(Color.black.opacity(0.78))
                .background(
                    LinearGradient(colors: [color.paper, color.paper.opacity(0.88)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
    }

    private func note(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .medium, design: .rounded))
            .lineSpacing(2)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
