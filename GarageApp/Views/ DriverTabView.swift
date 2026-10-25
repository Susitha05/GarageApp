import SwiftUI

struct DriverTabView: View {
    var body: some View {
        TabView {
            DriverJobsView().tabItem { Label("Jobs", systemImage: "list.bullet.rectangle") }
            DriverActiveJobView().tabItem { Label("Active", systemImage: "location.fill") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview { DriverTabView().environment(AppState(role: .towDriver)) }
