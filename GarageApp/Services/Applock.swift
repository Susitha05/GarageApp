import Foundation
import LocalAuthentication

/// Face ID / Touch ID / passcode lock. Locks when the app goes to the background and on cold launch.
@Observable
final class AppLock {
    static let shared = AppLock()
    private static let key = "faceIDLockEnabled"

    private(set) var isEnabled: Bool
    var isLocked: Bool
    var errorMessage: String?
    let biometryName: String

    private init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.key)
        isEnabled = enabled
        isLocked = enabled

        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: biometryName = "Face ID"
        case .touchID: biometryName = "Touch ID"
        default: biometryName = "Passcode"
        }
    }

    func lockIfNeeded() { if isEnabled { isLocked = true } }
    func markUnlocked() { isLocked = false }
    func reset() { isLocked = false }

    @MainActor
    func setEnabled(_ on: Bool) async {
        if on {
            guard await evaluate(reason: "Turn on app lock") else { return }
            isEnabled = true
        } else {
            isEnabled = false
            isLocked = false
        }
        UserDefaults.standard.set(isEnabled, forKey: Self.key)
    }

    @MainActor
    func unlock() async {
        if await evaluate(reason: "Unlock Smart Garage") { isLocked = false }
    }

    /// Uses Face ID and falls back to the device passcode so the user can never be locked out.
    @MainActor
    private func evaluate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = friendly(error)
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch let laError as LAError where [.userCancel, .appCancel, .systemCancel].contains(laError.code) {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func friendly(_ error: NSError?) -> String {
        guard let error, let code = LAError.Code(rawValue: error.code) else {
            return "Biometric authentication isn't available on this device."
        }
        switch code {
        case .passcodeNotSet:
            return "No passcode is set on this device. Set one (or enroll Face ID) first. In the Simulator: Features ▸ Face ID ▸ Enrolled."
        case .biometryNotEnrolled:
            return "Face ID isn't set up. In the Simulator: Features ▸ Face ID ▸ Enrolled."
        case .biometryNotAvailable:
            return "Face ID isn't available on this device."
        default:
            return error.localizedDescription
        }
    }
}
