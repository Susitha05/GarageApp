import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    private let lock = AppLock.shared
    @State private var pushEnabled = true
    @State private var maintenanceAlerts = true
    @State private var towUpdates = true

    private var lockBinding: Binding<Bool> {
        Binding(get: { lock.isEnabled }, set: { value in Task { await lock.setEnabled(value) } })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: ProfileView()) {
                        HStack(spacing: 14) {
                            AvatarView(data: app.profileImageData, size: 52)
                            VStack(alignment: .leading) {
                                Text(app.userName).font(.headline)
                                Text(app.email).font(.caption).foregroundStyle(.secondary)
                                Text(app.role?.rawValue ?? "").font(.caption).foregroundStyle(.blue)
                            }
                        }
                    }
                }
                Section {
                    Toggle("Unlock with \(lock.biometryName)", isOn: lockBinding)
                } header: {
                    Text("Security")
                } footer: {
                    Text("Locks the app when you leave it and asks for \(lock.biometryName) or your device passcode when you return.")
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
            .alert("Security", isPresented: Binding(get: { lock.errorMessage != nil },
                                                    set: { if !$0 { lock.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(lock.errorMessage ?? "")
            }
        }
    }
}

#Preview { SettingsView().environment(AppState(role: .customer)) }
