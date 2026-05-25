import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: SpotifyAuthManager
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "music.note.tv")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("tuneLink")
                .font(.largeTitle.bold())

            Text("Connect with Spotify to see what your partner is listening to.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Button {
                Task { await login() }
            } label: {
                Label("Connect with Spotify", systemImage: "music.note")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }
            .disabled(isAuthenticating)

            Spacer()
        }
    }

    private func login() async {
        isAuthenticating = true
        errorMessage = nil
        do {
            try await authManager.authenticate(presentationAnchor: ASPresentationAnchor())
        } catch {
            errorMessage = error.localizedDescription
        }
        isAuthenticating = false
    }
}
