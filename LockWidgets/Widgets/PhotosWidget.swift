import SwiftUI

struct PhotosWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var photos = PhotosStore.shared

    var body: some View {
        if let image = photos.image {
            if instance.style == "framed" {
                framed(image)
            } else {
                WidgetCard(size: instance.size, padding: 0) {
                    picture(image)
                }
            }
        } else {
            WidgetCard(size: instance.size, title: "Photos", symbol: "photo.on.rectangle") {
                WidgetPlaceholder(symbol: "photo", message: photos.problem ?? "Loading photos…")
            }
        }
    }

    private func picture(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    private func framed(_ image: NSImage) -> some View {
        let size = instance.size.points
        let border: CGFloat = instance.size == .large ? 14 : 9
        return VStack(spacing: border * 0.8) {
            picture(image)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            if let date = photos.date {
                Text(date.formatted(.dateTime.day().month(.wide).year()))
                    .font(.system(size: instance.size == .large ? 14 : 10, weight: .medium, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.6))
            }
        }
        .padding(border)
        .padding(.bottom, border)
        .frame(width: size.width, height: size.height)
        .background(Color(white: 0.97), in: RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .rotationEffect(.degrees(-2))
    }
}
