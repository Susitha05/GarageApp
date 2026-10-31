import SwiftUI

struct CustomerTabView: View {
    @State private var selection = 0
    @AppStorage("pendingTab") private var pendingTab = ""

    var body: some View {
        TabView(selection: $selection) {
            CustomerHomeView().tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            VehicleListView().tabItem { Label("Vehicles", systemImage: "car.fill") }.tag(1)
            ScheduleServiceView().tabItem { Label("Book", systemImage: "calendar.badge.plus") }.tag(2)
            TowRequestView().tabItem { Label("Tow", systemImage: "truck.box.fill") }.tag(3)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(4)
        }
        .onAppear(perform: route)
        .onChange(of: pendingTab) { _, _ in route() }
    }

    private func route() {
        if pendingTab == "tow" {
            selection = 3
            pendingTab = ""
        }
    }
}

#Preview {
    CustomerTabView()
        .environment(AppState(role: .customer))
        .environment(AuthService.preview(user: AppUser(uid: "c1", name: "Sasanka", email: "s@example.com", role: .customer)))
}
