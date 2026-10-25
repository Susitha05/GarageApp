import SwiftUI

@main
struct GarageApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}

/// Switches between the role picker (mock sign-in) and each role's tab UI.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Group {
            if let role = app.role {
                switch role {
                case .customer: CustomerTabView()
                case .garageOwner: GarageTabView()
                case .towDriver: DriverTabView()
                }
            } else {
                RoleSelectionView()
            }
        }
        .animation(.easeInOut, value: app.role)
    }
}

#Preview("Root – signed out") {
    RootView().environment(AppState())
}
