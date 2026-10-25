import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var app = app
        Form {
            Section("Personal info") {
                TextField("Full name", text: $app.userName)
                TextField("Email", text: $app.email)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never)
            }
            Section {
                Button("Save") { dismiss() }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { NavigationStack { ProfileView() }.environment(AppState(role: .customer)) }
