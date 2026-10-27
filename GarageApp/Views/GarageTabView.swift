import SwiftUI

struct GarageTabView: View {
    var body: some View {
        TabView {
            GarageDashboardView().tabItem { Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis") }
            AppointmentsView().tabItem { Label("Appointments", systemImage: "calendar") }
            InventoryView().tabItem { Label("Inventory", systemImage: "shippingbox.fill") }
            InsightsView().tabItem { Label("Insights", systemImage: "brain.head.profile") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    GarageTabView()
        .environment(AppState(role: .garageOwner))
        .environment(AuthService.preview(user: AppUser(uid: "g1", name: "Sasanka", email: "s@example.com", role: .garageOwner)))
}
