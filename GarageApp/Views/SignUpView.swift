import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var auth
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var role: UserRole = .customer

    private var validationMessage: String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter your name." }
        if !AuthService.isValidEmail(email.trimmingCharacters(in: .whitespaces)) { return "Enter a valid email address." }
        if password.count < 6 { return "Password must be at least 6 characters." }
        if password != confirm { return "Passwords don't match." }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Create account").font(.largeTitle.bold())

                VStack(spacing: 12) {
                    field { TextField("Full name", text: $name).textContentType(.name) }
                    field {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    field { SecureField("Password (min 6 characters)", text: $password).textContentType(.newPassword) }
                    field { SecureField("Confirm password", text: $confirm).textContentType(.newPassword) }
                }

                Text("I am a…").font(.headline)
                RolePicker(selection: $role)

                if let message = validationMessage, !(name.isEmpty && email.isEmpty && password.isEmpty) {
                    Label(message, systemImage: "info.circle").font(.footnote).foregroundStyle(.orange)
                }

                Button {
                    Task { await auth.signUp(name: name, email: email, password: password, role: role) }
                } label: {
                    Group {
                        if auth.isBusy { ProgressView().tint(.white) } else { Text("Create account") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(validationMessage != nil || auth.isBusy)

                OrDivider()

                GoogleButton(title: "Sign up with Google") { Task { await auth.signInWithGoogle() } }
                    .disabled(auth.isBusy)
                Text("With Google you'll choose your role on the next screen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .authAlerts()
    }

    private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview { NavigationStack { SignUpView() }.environment(AuthService.preview()) }
