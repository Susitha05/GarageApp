import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var faceID = true
    @State private var pushEnabled = true
    @State private var maintenanceAlerts = true
    @State private var towUpdates = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 44)).foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(app.userName).font(.headline)
                            Text(app.email).font(.caption).foregroundStyle(.secondary)
                            Text(app.role?.rawValue ?? "").font(.caption).foregroundStyle(.blue)
                        }
                    }
                    NavigationLink("Edit profile", destination: ProfileView())
                }
                Section("Security") {
                    Toggle("Unlock with Face ID", isOn: $faceID)
                }
                Section("Notifications") {
                    Toggle("Push notifications", isOn: $pushEnabled)
                    Toggle("Maintenance alerts", isOn: $maintenanceAlerts).disabled(!pushEnabled)
                    Toggle("Tow status updates", isOn: $towUpdates).disabled(!pushEnabled)
                    NavigationLink("Notification history", destination: NotificationsView())
                }
                Section {
                    Button("Sign out", role: .destructive) { app.signOut() }
                } footer: {
                    Text("Signed in as \(app.email)")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview { SettingsView().environment(AppState(role: .customer)) }
