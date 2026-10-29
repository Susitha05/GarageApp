import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct GarageApp: App {
    @State private var appState: AppState
    @State private var auth: AuthService

    init() {
        FirebaseApp.configure()               // needs GoogleService-Info.plist in the app target
        // Created after configure() so AppState knows Firebase is available.
        _appState = State(initialValue: AppState())
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

/// Routes by auth state, starts the Firestore listeners for the signed-in role,
/// and covers the app with the Face ID lock when enabled.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(AuthService.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    private let lock = AppLock.shared
    private let cloud = CloudStore.shared

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
        .task(id: auth.user?.uid) { startListeners() }
        .onChange(of: auth.user) { _, user in
            guard let user else { return }
            app.role = user.role
            app.userName = user.name
            app.email = user.email
            app.userUid = user.uid
            app.profileImageData = user.photoData
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lockIfNeeded() }
        }
        .alert("Sync problem", isPresented: Binding(get: { cloud.errorMessage != nil },
                                                    set: { if !$0 { cloud.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cloud.errorMessage ?? "")
        }
    }
}

extension RootView {
    /// Listeners follow the login state: they restart after every sign-in and stop on sign-out.
    private func startListeners() {
        guard let user = auth.user else {
            TowService.shared.stop()
            CloudStore.shared.stop()
            app.clearCloudData()
            return
        }
        app.userUid = user.uid
        if user.uid == "dev" {
            app.loadDemoData()                                  // skip-login mode: local demo data
        } else {
            CloudStore.shared.start(user: user, app: app)       // appointments, inventory, receipts
        }
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
