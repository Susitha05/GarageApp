import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

// MARK: - Types

struct AppUser: Equatable {
    var uid: String
    var name: String
    var email: String
    var role: UserRole
}

/// Signed in with Firebase but no Firestore profile yet (e.g. first Google sign-in).
struct PendingProfile: Equatable {
    var uid: String
    var name: String
    var email: String
}

enum AuthPhase: Equatable {
    case loading
    case signedOut
    case needsRole(PendingProfile)
    case signedIn(AppUser)
}

struct Notice: Equatable {
    var title: String
    var message: String
}

extension UserRole {
    /// Value stored in Firestore.
    var code: String {
        switch self {
        case .customer: "customer"
        case .garageOwner: "garageOwner"
        case .towDriver: "towDriver"
        }
    }
    init?(code: String) {
        guard let role = UserRole.allCases.first(where: { $0.code == code }) else { return nil }
        self = role
    }
}

// MARK: - Service

/// Firebase Auth + Firestore profile (role). Pass `usesFirebase: false` (see `preview`) for SwiftUI previews.
@Observable
final class AuthService {
    var phase: AuthPhase = .loading
    var isBusy = false
    var notice: Notice?

    var user: AppUser? {
        if case .signedIn(let u) = phase { return u }
        return nil
    }

    @ObservationIgnored private let usesFirebase: Bool
    @ObservationIgnored private var listener: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var suppressListener = false

    init(usesFirebase: Bool = true) { self.usesFirebase = usesFirebase }

    static func preview(user: AppUser? = nil) -> AuthService {
        let service = AuthService(usesFirebase: false)
        service.phase = user.map { .signedIn($0) } ?? .signedOut
        return service
    }

    // MARK: Lifecycle

    func start() {
        guard usesFirebase, listener == nil else { return }
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self, !self.suppressListener else { return }
            Task { @MainActor in await self.resolve(firebaseUser) }
        }
    }

    @MainActor
    private func resolve(_ firebaseUser: FirebaseAuth.User?) async {
        guard let firebaseUser else { phase = .signedOut; return }
        do {
            if let profile = try await fetchProfile(uid: firebaseUser.uid) {
                phase = .signedIn(profile)
            } else {
                phase = .needsRole(PendingProfile(uid: firebaseUser.uid,
                                                  name: firebaseUser.displayName ?? "",
                                                  email: firebaseUser.email ?? ""))
            }
        } catch {
            showError(message(for: error))
            try? Auth.auth().signOut()
            phase = .signedOut
        }
    }

    // MARK: Email / password

    @MainActor
    func signIn(email: String, password: String) async {
        guard usesFirebase else { return }
        isBusy = true; defer { isBusy = false }
        do {
            _ = try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            showError(message(for: error))
        }
    }

    @MainActor
    func signUp(name: String, email: String, password: String, role: UserRole) async {
        guard usesFirebase else { return }
        isBusy = true
        suppressListener = true
        defer { isBusy = false; suppressListener = false }

        let cleanEmail = email.trimmingCharacters(in: .whitespaces)
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        do {
            let result = try await Auth.auth().createUser(withEmail: cleanEmail, password: password)
            let change = result.user.createProfileChangeRequest()
            change.displayName = cleanName
            try? await change.commitChanges()
            try await saveProfile(uid: result.user.uid, name: cleanName, email: cleanEmail, role: role)
            phase = .signedIn(AppUser(uid: result.user.uid, name: cleanName, email: cleanEmail, role: role))
        } catch {
            showError(message(for: error))
            // Account exists but the profile write failed – let the user retry from the role screen.
            if let current = Auth.auth().currentUser {
                phase = .needsRole(PendingProfile(uid: current.uid, name: cleanName, email: cleanEmail))
            }
        }
    }

    @MainActor
    func sendPasswordReset(email: String) async {
        guard usesFirebase else { return }
        let clean = email.trimmingCharacters(in: .whitespaces)
        guard Self.isValidEmail(clean) else { showError("Enter your email address first."); return }
        isBusy = true; defer { isBusy = false }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: clean)
            notice = Notice(title: "Check your inbox", message: "If an account exists for \(clean), a reset link has been sent.")
        } catch {
            showError(message(for: error))
        }
    }

    // MARK: Google

    @MainActor
    func signInWithGoogle() async {
        guard usesFirebase else { return }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            showError("Google Sign-In isn't configured. Check GoogleService-Info.plist.")
            return
        }
        guard let presenter = Self.topViewController() else { return }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        isBusy = true; defer { isBusy = false }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                showError("Google did not return a valid token.")
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: result.user.accessToken.tokenString)
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            let ns = error as NSError
            if ns.domain == kGIDSignInErrorDomain, ns.code == GIDSignInError.canceled.rawValue { return }
            showError(message(for: error))
        }
    }

    // MARK: Profile / role

    @MainActor
    func completeProfile(_ pending: PendingProfile, name: String, role: UserRole) async {
        guard usesFirebase else { return }
        isBusy = true; defer { isBusy = false }
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        do {
            try await saveProfile(uid: pending.uid, name: cleanName, email: pending.email, role: role)
            phase = .signedIn(AppUser(uid: pending.uid, name: cleanName, email: pending.email, role: role))
        } catch {
            showError(message(for: error))
        }
    }

    func signOut() {
        if usesFirebase {
            try? Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        }
        phase = .signedOut
    }

    #if DEBUG
    /// Skips Firebase so screens can be explored without an account.
    func devSignIn(as role: UserRole) {
        phase = .signedIn(AppUser(uid: "dev", name: "Preview User", email: "preview@example.com", role: role))
    }
    #endif

    // MARK: Firestore

    private func fetchProfile(uid: String) async throws -> AppUser? {
        let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
        guard let data = snapshot.data(),
              let code = data["role"] as? String,
              let role = UserRole(code: code) else { return nil }
        return AppUser(uid: uid,
                       name: data["name"] as? String ?? "",
                       email: data["email"] as? String ?? "",
                       role: role)
    }

    private func saveProfile(uid: String, name: String, email: String, role: UserRole) async throws {
        try await Firestore.firestore().collection("users").document(uid).setData([
            "name": name,
            "email": email,
            "role": role.code,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: Helpers

    func showError(_ text: String) { notice = Notice(title: "Something went wrong", message: text) }

    static func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private func message(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == "FIRAuthErrorDomain", let code = AuthErrorCode.Code(rawValue: ns.code) {
            switch code {
            case .wrongPassword, .invalidCredential, .userNotFound: return "Incorrect email or password."
            case .emailAlreadyInUse: return "An account with this email already exists. Try signing in."
            case .weakPassword: return "Password must be at least 6 characters."
            case .invalidEmail: return "That email address isn't valid."
            case .networkError: return "Network error. Check your connection and try again."
            case .tooManyRequests: return "Too many attempts. Please wait a moment and try again."
            default: break
            }
        }
        return ns.localizedDescription
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
