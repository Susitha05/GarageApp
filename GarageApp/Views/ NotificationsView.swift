import SwiftUI

struct NotificationsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        List(app.notifications) { n in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: n.icon).foregroundStyle(.blue).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(n.title).font(.subheadline.weight(.semibold))
                    Text(n.body).font(.caption).foregroundStyle(.secondary)
                    Text(n.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { NavigationStack { NotificationsView() }.environment(AppState(role: .customer)) }
