import SwiftUI

/// Temporary stand-in for the login screen. No Firebase / auth calls are made.
struct RoleSelectionView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 56)).foregroundStyle(.blue)
                    Text("Smart Garage").font(.largeTitle.bold())
                    Text("Preview mode – pick a role to explore")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                ForEach(UserRole.allCases) { role in
                    Button { app.role = role } label: {
                        HStack(spacing: 16) {
                            Image(systemName: role.icon).font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.rawValue).font(.headline)
                                Text(role.blurb).font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Continue as \(role.rawValue)")
                }

                Label("Email, Google Sign-In and Face ID will be added with Firebase", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

#Preview { RoleSelectionView().environment(AppState()) }
