import SwiftUI

struct WidgetView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(alignment: .leading, spacing: 8) {
                Text(ctx.date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                Text(ctx.date, format: .dateTime.weekday(.wide).day().month())
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
