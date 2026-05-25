import SwiftUI

struct PairingView: View {
    private let baseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "http://localhost:3000"
    }()

    private var userId: String {
        UserDefaults(suiteName: AppGroup.suiteName)?.string(forKey: AppGroup.Keys.userId) ?? ""
    }

    @State private var inviteCode: String = ""
    @State private var partnerCode: String = ""
    @State private var isLoadingInvite = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var paired = false

    var body: some View {
        NavigationStack {
            Form {
                // 11.1a — Your invite code
                Section("Your Invite Code") {
                    if isLoadingInvite {
                        ProgressView()
                    } else if inviteCode.isEmpty {
                        Text("Tap to generate")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text(inviteCode)
                                .font(.system(.title2, design: .monospaced).bold())
                            Spacer()
                            Button {
                                UIPasteboard.general.string = inviteCode
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    }
                }

                // 11.1b — Enter partner's code
                Section("Enter Partner's Code") {
                    TextField("e.g. A3F9B2", text: $partnerCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)

                    Button("Pair") {
                        Task { await submitPairing() }
                    }
                    .disabled(partnerCode.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }

                if let msg = errorMessage {
                    Section {
                        Text(msg).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Pair with Partner")
            .onAppear {
                Task { await fetchInviteCode() }
            }
            .alert("Paired!", isPresented: $paired) {
                Button("OK") {}
            } message: {
                Text("You're now connected to your partner.")
            }
        }
    }

    private func fetchInviteCode() async {
        guard !userId.isEmpty else { return }
        isLoadingInvite = true
        defer { isLoadingInvite = false }

        do {
            let url = URL(string: "\(baseURL)/pair/invite")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(["userId": userId])

            let (data, _) = try await URLSession.shared.data(for: req)
            let body = try JSONDecoder().decode([String: String].self, from: data)
            inviteCode = body["inviteCode"] ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 11.2 — POST { inviteCode, userId }, store pairId
    private func submitPairing() async {
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        do {
            let url = URL(string: "\(baseURL)/pair")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode([
                "inviteCode": partnerCode.trimmingCharacters(in: .whitespaces),
                "userId": userId,
            ])

            let (data, _) = try await URLSession.shared.data(for: req)
            let body = try JSONDecoder().decode([String: String].self, from: data)

            guard let pairId = body["pairId"] else {
                errorMessage = body["error"] ?? "Unknown error"
                return
            }

            UserDefaults(suiteName: AppGroup.suiteName)?.set(pairId, forKey: AppGroup.Keys.pairId)
            paired = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
