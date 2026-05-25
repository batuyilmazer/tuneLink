import SwiftUI

private enum PairingStep {
    case shareCode, enterCode, connected
}

struct PairingView: View {
    private let baseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "http://localhost:3000"
    }()

    private var defaults: UserDefaults? { UserDefaults(suiteName: AppGroup.suiteName) }

    private var userId: String { defaults?.string(forKey: AppGroup.Keys.userId) ?? "" }

    @State private var step: PairingStep = .shareCode
    @State private var inviteCode: String = ""
    @State private var partnerCode: String = ""
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .shareCode:
                    ShareCodeView(
                        inviteCode: inviteCode,
                        isLoading: isLoading,
                        onEnterCode: { step = .enterCode }
                    )
                case .enterCode:
                    EnterCodeView(
                        partnerCode: $partnerCode,
                        isSubmitting: isSubmitting,
                        errorMessage: errorMessage,
                        onBack: { step = .shareCode; errorMessage = nil },
                        onPair: { Task { await submitPairing() } }
                    )
                case .connected:
                    ConnectedView(onUnpair: unpair)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { initialize() }
    }

    private var navigationTitle: String {
        switch step {
        case .shareCode: return "Eşleş"
        case .enterCode: return "Kodu Gir"
        case .connected: return "Bağlı"
        }
    }

    // MARK: - Init

    private func initialize() {
        if defaults?.string(forKey: AppGroup.Keys.pairId) != nil {
            step = .connected
            return
        }
        if let stored = defaults?.string(forKey: AppGroup.Keys.inviteCode), !stored.isEmpty {
            inviteCode = stored
        } else {
            Task { await fetchInviteCode() }
        }
    }

    // MARK: - Network

    private func fetchInviteCode() async {
        guard !userId.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var req = URLRequest(url: URL(string: "\(baseURL)/pair/invite")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(["userId": userId])

            let (data, _) = try await URLSession.shared.data(for: req)
            let body = try JSONDecoder().decode([String: String].self, from: data)
            if let code = body["inviteCode"] {
                inviteCode = code
                defaults?.set(code, forKey: AppGroup.Keys.inviteCode)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitPairing() async {
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        do {
            var req = URLRequest(url: URL(string: "\(baseURL)/pair")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode([
                "inviteCode": partnerCode.trimmingCharacters(in: .whitespaces),
                "userId": userId,
            ])

            let (data, _) = try await URLSession.shared.data(for: req)
            let body = try JSONDecoder().decode([String: String].self, from: data)

            guard let pairId = body["pairId"] else {
                errorMessage = body["error"] ?? "Geçersiz veya süresi dolmuş kod."
                return
            }

            defaults?.set(pairId, forKey: AppGroup.Keys.pairId)
            defaults?.removeObject(forKey: AppGroup.Keys.inviteCode)
            step = .connected
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Unpair

    private func unpair() {
        defaults?.removeObject(forKey: AppGroup.Keys.pairId)
        defaults?.removeObject(forKey: AppGroup.Keys.inviteCode)
        inviteCode = ""
        partnerCode = ""
        errorMessage = nil
        step = .shareCode
        Task { await fetchInviteCode() }
    }
}

// MARK: - Step 1: Share Code

private struct ShareCodeView: View {
    let inviteCode: String
    let isLoading: Bool
    let onEnterCode: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("Kodunu paylaş")
                    .font(.title2.bold())

                Text("Bu kodu partnerine gönder. Partner bu kodu uygulamaya girdikten sonra bağlanırsınız.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if isLoading {
                    ProgressView()
                        .frame(height: 64)
                } else {
                    Text(inviteCode.isEmpty ? "------" : inviteCode)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .tracking(8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = inviteCode
                    } label: {
                        Label("Kopyala", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(inviteCode.isEmpty)

                    if !inviteCode.isEmpty {
                        ShareLink(item: "tuneLink davet kodum: \(inviteCode)") {
                            Label("Paylaş", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                Text("10 dakika geçerlidir")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Divider()

            Button(action: onEnterCode) {
                HStack {
                    Text("Partnerimin kodu var")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .foregroundStyle(.primary)
        }
    }
}

// MARK: - Step 2: Enter Code

private struct EnterCodeView: View {
    @Binding var partnerCode: String
    let isSubmitting: Bool
    let errorMessage: String?
    let onBack: () -> Void
    let onPair: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("Partnerin kodunu gir")
                    .font(.title2.bold())

                Text("Partnerin size ilettiği 6 haneli kodu gir.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            TextField("A3F9B2", text: $partnerCode)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .tracking(6)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

            if let msg = errorMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: onPair) {
                Group {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Eşleş")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(partnerCode.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
            .padding(.horizontal)

            Spacer()

            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Kendi koduma dön")
                }
                .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom)
        }
    }
}

// MARK: - Step 3: Connected

private struct ConnectedView: View {
    let onUnpair: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("Bağlandınız!")
                        .font(.title.bold())

                    Text("Artık partnerinin dinlediklerini widget'ta görebilirsin.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                Text("Widget'ı nasıl eklersin")
                    .font(.headline)
                    .padding(.bottom, 16)

                widgetStep("1", "Ana ekranı uzun bas")
                widgetStep("2", "Sol üstteki \"+\" ye dokun")
                widgetStep("3", "\"tuneLink\" ara ve widget'ı ekle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            Button(role: .destructive, action: onUnpair) {
                Text("Eşleşmeyi sıfırla")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom)
        }
    }

    private func widgetStep(_ number: String, _ label: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(.callout, design: .rounded).bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.green)
                .clipShape(Circle())

            Text(label)
                .font(.subheadline)
        }
        .padding(.bottom, 14)
    }
}
