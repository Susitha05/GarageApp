import SwiftUI
import UIKit

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = .blue
    var body: some View {
        Card {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.headline).accessibilityAddTraits(.isHeader)
    }
}

#Preview("Components") {
    VStack(spacing: 12) {
        StatTile(title: "Vehicles", value: "2", icon: "car.fill")
        StatusBadge(text: "Pending", color: .orange)
        Card { SectionTitle("Card title"); Text("Body") }
    }
    .padding()
}

struct AvatarView: View {
    var data: Data?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.blue)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("Profile picture")
    }
}
