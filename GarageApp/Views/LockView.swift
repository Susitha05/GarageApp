import SwiftUI

struct LockView: View {
    @Environment(AppState.self) private var app
    private let lock = AppLock.shared

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: lock.biometryName == "Passcode" ? "lock.fill" : "faceid")
                    .font(.system(size: 64)).foregroundStyle(.blue)
                Text("Smart Garage is locked").font(.title3.bold())
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Text("Unlock with \(lock.biometryName)").frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Sign out", role: .destructive) { app.signOut() }
                    .font(.footnote)
            }
            .padding()
        }
        .task { await lock.unlock() }     // prompt immediately
    }
}

#Preview { LockView().environment(AppState()) }
