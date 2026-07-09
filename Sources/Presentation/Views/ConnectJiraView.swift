import SwiftUI

struct ConnectJiraView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage("jira.clientID") private var clientID = ""
    @AppStorage("jira.redirectURI") private var redirectURI = "myjira://oauth/callback"

    @State private var clientSecret = ""

    let isConnecting: Bool
    let onConnect: (JiraOAuthConfiguration) -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("myJIRA")
                        .font(.headingXL)

                    Text("Synchronise tes workspaces, projets et backlog dans un client macOS local-first.")
                        .font(.paragraphM)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 16) {
                    OAuthField(title: "Client ID") {
                        TextField("Atlassian OAuth client ID", text: $clientID)
                            .textContentType(.username)
                    }

                    OAuthField(title: "Client Secret") {
                        SecureField("Atlassian OAuth client secret", text: $clientSecret)
                            .textContentType(.password)
                    }

                    OAuthField(title: "Redirect URI") {
                        TextField("myjira://oauth/callback", text: $redirectURI)
                            .textContentType(.URL)
                    }

                    Button {
                        connect()
                    } label: {
                        HStack(spacing: 8) {
                            if isConnecting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.foreground)
                            }
                            Text("Connect Jira")
                        }
                    }
                    .buttonStyle(JiraPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(isConnecting || clientID.isEmpty || clientSecret.isEmpty || URL(string: redirectURI) == nil)
                }
                .frame(width: 430)
            }
            .frame(width: 520)
        }
        .task {
            loadStoredSecret()
        }
    }

    private func connect() {
        guard let redirectURL = URL(string: redirectURI) else { return }

        onConnect(JiraOAuthConfiguration(
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURL,
            scopes: ["read:jira-user", "read:jira-work", "write:jira-work", "offline_access"]
        ))
    }

    private func loadStoredSecret() {
        guard clientSecret.isEmpty else { return }

        do {
            if let data = try container.secretStore.read(account: "jira.oauth.clientSecret"),
               let secret = String(data: data, encoding: .utf8) {
                clientSecret = secret
            }
        } catch {
            // The main connect action will surface actionable auth errors.
        }
    }
}

private struct OAuthField<Field: View>: View {
    let title: String
    @ViewBuilder var field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.labelS)
                .foregroundStyle(.secondary)
            field
                .jiraCapsuleFieldStyle()
        }
    }
}
