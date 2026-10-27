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

/// Routes by auth state, and covers the app with the Face ID lock when enabled.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(AuthService.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    private let lock = AppLock.shared

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
        .overlay {
            if lock.isLocked && auth.user != nil { LockView() }
        }
        .task {
            app.signOutHandler = { auth.signOut() }
            auth.start()
        }
        .task(id: auth.user?.uid) { startTowListeners() }
        .onChange(of: auth.user) { _, user in
            guard let user else { return }
            app.role = user.role
            app.userName = user.name
            app.email = user.email
            app.profileImageData = user.photoData
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lockIfNeeded() }
        }
    }
}

extension RootView {
    /// Tow listeners follow the login state, so they restart after every sign-in and stop on sign-out.
    private func startTowListeners() {
        guard let user = auth.user else { TowService.shared.stop(); return }
        switch user.role {
        case .customer: TowService.shared.listenAsCustomer(uid: user.uid)
        case .towDriver: TowService.shared.listenAsDriver(uid: user.uid)
        case .garageOwner: break
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
