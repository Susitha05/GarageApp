import SwiftUI

/// Shown after a first-time Google sign-in (or if a profile write failed).
struct ChooseRoleView: View {
    @Environment(AuthService.self) private var auth
    let pending: PendingProfile
    @State private var name: String
    @State private var role: UserRole = .customer

    init(pending: PendingProfile) {
        self.pending = pending
        _name = State(initialValue: pending.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Welcome!").font(.largeTitle.bold())
                Text("Signed in as \(pending.email). Tell us how you'll use the app.")
                    .foregroundStyle(.secondary)

                TextField("Full name", text: $name)
                    .textContentType(.name)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                Text("I am a…").font(.headline)
                RolePicker(selection: $role)

                Button {
                    Task { await auth.completeProfile(pending, name: name, role: role) }
                } label: {
                    Group {
                        if auth.isBusy { ProgressView().tint(.white) } else { Text("Continue") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || auth.isBusy)

                Button("Use a different account", role: .cancel) { auth.signOut() }
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .authAlerts()
    }
}

#Preview {
    ChooseRoleView(pending: PendingProfile(uid: "1", name: "Sasanka", email: "sasanka@example.com"))
        .environment(AuthService.preview())
}
