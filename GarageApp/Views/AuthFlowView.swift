import SwiftUI

struct AuthFlowView: View {
    var body: some View {
        NavigationStack { LoginView() }
    }
}

#Preview { AuthFlowView().environment(AuthService.preview()) }
