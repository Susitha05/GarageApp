import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct GarageApp: App {
    @State private var appState = AppState()
    @State private var auth: AuthService

    init() {
        FirebaseApp.configure()               // needs GoogleService-Info.plist in the app target
        _auth = State(initialValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(auth)
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }   // Google Sign-In redirect
        }
    }
}

/// Routes by auth state: login/sign-up → role selection (new Google users) → role-specific tabs.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(AuthService.self) private var auth

    var body: some View {
        Group {
            switch auth.phase {
            case .loading:
                ProgressView("Loading…")
            case .signedOut:
                AuthFlowView()
            case .needsRole(let pending):
                ChooseRoleView(pending: pending)
            case .signedIn(let user):
                switch user.role {
                case .customer: CustomerTabView()
                case .garageOwner: GarageTabView()
                case .towDriver: DriverTabView()
                }
            }
        }
        .animation(.easeInOut, value: auth.phase)
        .task {
            app.signOutHandler = { auth.signOut() }
            auth.start()
        }
        .onChange(of: auth.user) { _, user in
            guard let user else { return }
            app.role = user.role
            app.userName = user.name
            app.email = user.email
        }
    }
}

#Preview("Signed out") {
    RootView().environment(AppState()).environment(AuthService.preview())
}

#Preview("Signed in – garage owner") {
    RootView()
        .environment(AppState(role: .garageOwner))
        .environment(AuthService.preview(user: AppUser(uid: "1", name: "Sasanka", email: "s@example.com", role: .garageOwner)))
}
