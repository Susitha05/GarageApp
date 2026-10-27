import SwiftUI

struct CustomerTabView: View {
    var body: some View {
        TabView {
            CustomerHomeView().tabItem { Label("Home", systemImage: "house.fill") }
            VehicleListView().tabItem { Label("Vehicles", systemImage: "car.fill") }
            ScheduleServiceView().tabItem { Label("Book", systemImage: "calendar.badge.plus") }
            TowRequestView().tabItem { Label("Tow", systemImage: "truck.box.fill") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    CustomerTabView()
        .environment(AppState(role: .customer))
        .environment(AuthService.preview(user: AppUser(uid: "c1", name: "Sasanka", email: "s@example.com", role: .customer)))
}
