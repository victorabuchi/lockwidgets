import SwiftUI

struct StickyNotesPage: View {
    @ObservedObject private var layout = LayoutStore.shared

    var body: some View {
        let notes = layout.instances.filter { $0.kind == .stickyNote }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    PageHeader(title: "Sticky Notes", subtitle: "Reminders to yourself, waiting on the lock screen.")
                    Button {
                        let id = layout.add(.stickyNote, style: "paper", size: .medium)
                        layout.update(id) { $0.config["color"] = NoteColor.allCases.randomElement()!.rawValue }
                    } label: {
                        Label("New Note", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if notes.isEmpty {
                    PreviewStage(height: 260) {
                        VStack(spacing: 14) {
                            StickyNoteWidget(instance: WidgetKind.stickyNote.sample(size: .medium))
                            Text("No notes yet. Add one and it appears on your lock screen.")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }

                ForEach(notes) { note in
                    Panel {
                        HStack(alignment: .top, spacing: 18) {
                            FittedWidget(instance: note, box: CGSize(width: 240, height: 200))
                                .frame(width: 240)
                            VStack(alignment: .leading, spacing: 10) {
                                NoteEditor(instance: note)
                                HStack {
                                    Picker("Size", selection: binding(note, \.size)) {
                                        ForEach(WidgetKind.stickyNote.style(note.style).sizes) { Text($0.title).tag($0) }
                                    }
                                    .pickerStyle(.segmented)
                                    .fixedSize()
                                    Picker("Style", selection: binding(note, \.style)) {
                                        ForEach(WidgetKind.stickyNote.styles) { Text($0.name).tag($0.id) }
                                    }
                                    .fixedSize()
                                    Spacer()
                                    Button("Delete", role: .destructive) { layout.remove(note.id) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private func binding<Value>(_ note: WidgetInstance, _ path: WritableKeyPath<WidgetInstance, Value>) -> Binding<Value> {
        Binding {
            note[keyPath: path]
        } set: { value in
            LayoutStore.shared.update(note.id) { $0[keyPath: path] = value }
        }
    }
}

/// Text and colour for one note.
struct NoteEditor: View {
    let instance: WidgetInstance
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .font(.system(size: 14))
                .frame(minHeight: 70)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
                .onChange(of: text) {
                    LayoutStore.shared.update(instance.id) { $0.config["text"] = text }
                }
            HStack(spacing: 8) {
                ForEach(NoteColor.allCases) { color in
                    let selected = (instance.config["color"] ?? "yellow") == color.rawValue
                    Button {
                        LayoutStore.shared.update(instance.id) { $0.config["color"] = color.rawValue }
                    } label: {
                        Circle()
                            .fill(color.paper)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2).padding(-3))
                    }
                    .buttonStyle(.plain)
                    .help(color.rawValue.capitalized)
                }
            }
        }
        .onAppear { text = instance.config["text"] ?? "" }
    }
}
