import SwiftUI

struct DriverTabView: View {
    var body: some View {
        TabView {
            DriverJobsView().tabItem { Label("Jobs", systemImage: "list.bullet.rectangle") }
            DriverActiveJobView().tabItem { Label("Active", systemImage: "location.fill") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .task { LocationManager.shared.start() }
    }
}

#Preview {
    DriverTabView()
        .environment(AppState(role: .towDriver))
        .environment(AuthService.preview(user: AppUser(uid: "d1", name: "Saman", email: "saman@example.com", role: .towDriver)))
}
