import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage("jira.clientID") private var clientID = ""
    @AppStorage("jira.redirectURI") private var redirectURI = "myjira://oauth/callback"

    @State private var clientSecret = ""
    @State private var isConnecting = false
    @State private var resources: [JiraAccessibleResource] = []
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    settingsLabel("Jira OAuth")

                    TextField("Client ID", text: $clientID)
                        .textContentType(.username)
                        .jiraCapsuleFieldStyle()

                    SecureField("Client Secret", text: $clientSecret)
                        .textContentType(.password)
                        .jiraCapsuleFieldStyle()

                    TextField("Redirect URI", text: $redirectURI)
                        .textContentType(.URL)
                        .jiraCapsuleFieldStyle()

                    HStack(spacing: 12) {
                        Button {
                            Task { await connect() }
                        } label: {
                            if isConnecting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Connect")
                            }
                        }
                        .buttonStyle(JiraPrimaryButtonStyle(expandsToMaxWidth: false))
                        .disabled(isConnecting || clientID.isEmpty || clientSecret.isEmpty || URL(string: redirectURI) == nil)

                        Button("Disconnect") {
                            disconnect()
                        }
                        .buttonStyle(JiraSecondaryButtonStyle(expandsToMaxWidth: false))
                        .disabled(isConnecting)
                    }
                }
                .jiraPanel()

                if !resources.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        settingsLabel("Accessible Workspaces")

                        ForEach(resources) { resource in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(resource.name)
                                    .font(.labelM)
                                Text(resource.url.absoluteString)
                                    .font(.paragraphS)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }
                    .jiraPanel()
                }

                if let message {
                    Text(message)
                        .font(.paragraphS)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .jiraPanel(radius: JiraDesign.controlRadius, padding: 16)
                }
            }
            .padding(28)
        }
        .frame(width: 520, height: 420)
        .task {
            loadStoredSecret()
            loadConnectionState()
        }
    }

    private func settingsLabel(_ value: String) -> some View {
        Text(value.uppercased())
            .font(.labelXS)
            .foregroundStyle(.secondary)
    }

    private func connect() async {
        guard let redirectURL = URL(string: redirectURI) else {
            message = "Redirect URI invalide."
            return
        }

        isConnecting = true
        message = nil
        defer { isConnecting = false }

        do {
            let result = try await container.jiraConnectionService.connect(configuration: JiraOAuthConfiguration(
                clientID: clientID,
                clientSecret: clientSecret,
                redirectURI: redirectURL,
                scopes: JiraOAuthScopes.defaultScopes
            ))

            resources = result.resources
            NotificationCenter.default.post(name: .refreshRequested, object: nil)
            message = "Connecté à \(result.resources.count) workspace(s), \(result.projectCount) projet(s) synchronisé(s)."
        } catch {
            message = error.localizedDescription
        }
    }

    private func disconnect() {
        Task {
            do {
                try await container.jiraConnectionService.disconnect()
                NotificationCenter.default.post(name: .refreshRequested, object: nil)
                resources = []
                message = "Connexion Jira supprimée."
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func loadStoredSecret() {
        do {
            if let data = try container.secretStore.read(account: "jira.oauth.clientSecret"),
               let secret = String(data: data, encoding: .utf8) {
                clientSecret = secret
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func loadConnectionState() {
        do {
            if let token = try container.authService.currentToken() {
                message = "Token Jira stocké jusqu'à \(token.expiresAt.formatted(date: .abbreviated, time: .shortened))."
            }
        } catch {
            message = error.localizedDescription
        }
    }
}
