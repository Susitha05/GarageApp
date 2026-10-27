import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var auth
    @State private var email = ""
    @State private var password = ""

    private var canSubmit: Bool {
        AuthService.isValidEmail(email.trimmingCharacters(in: .whitespaces)) && password.count >= 6 && !auth.isBusy
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "car.side.fill").font(.system(size: 56)).foregroundStyle(.blue)
                    Text("Smart Garage").font(.largeTitle.bold())
                    Text("Sign in to continue").foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Spacer()
                        Button("Forgot password?") { Task { await auth.sendPasswordReset(email: email) } }
                            .font(.footnote)
                    }
                }

                Button {
                    Task { await auth.signIn(email: email, password: password) }
                } label: {
                    Group {
                        if auth.isBusy { ProgressView().tint(.white) } else { Text("Sign in") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSubmit)

                OrDivider()

                GoogleButton(title: "Continue with Google") { Task { await auth.signInWithGoogle() } }
                    .disabled(auth.isBusy)

                NavigationLink("Don't have an account? Sign up") { SignUpView() }
                    .font(.subheadline)
                    .padding(.top, 4)

                #if DEBUG
                Menu("Developer: skip login") {
                    ForEach(UserRole.allCases) { role in
                        Button(role.rawValue) { auth.devSignIn(as: role) }
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                #endif
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .authAlerts()
    }
}

#Preview { NavigationStack { LoginView() }.environment(AuthService.preview()) }
