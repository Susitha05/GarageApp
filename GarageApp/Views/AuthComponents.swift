import SwiftUI

/// Shows `AuthService.notice` (errors / info) as an alert.
struct AuthAlerts: ViewModifier {
    @Environment(AuthService.self) private var auth

    func body(content: Content) -> some View {
        content.alert(
            auth.notice?.title ?? "",
            isPresented: Binding(get: { auth.notice != nil },
                                 set: { if !$0 { auth.notice = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.notice?.message ?? "")
        }
    }
}

extension View {
    func authAlerts() -> some View { modifier(AuthAlerts()) }
}

struct RolePicker: View {
    @Binding var selection: UserRole

    var body: some View {
        VStack(spacing: 10) {
            ForEach(UserRole.allCases) { role in
                Button { selection = role } label: {
                    HStack(spacing: 14) {
                        Image(systemName: role.icon)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(role.rawValue).font(.subheadline.weight(.semibold))
                            Text(role.blurb).font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: selection == role ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection == role ? Color.blue : Color.secondary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(selection == role ? Color.blue : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(role.rawValue)
                .accessibilityAddTraits(selection == role ? .isSelected : [])
            }
        }
    }
}

struct GoogleButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "g.circle.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

struct OrDivider: View {
    var body: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            Text("or").font(.caption).foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
        }
    }
}

#Preview("Role picker") {
    RolePicker(selection: .constant(.customer)).padding()
}
