import SwiftUI

struct ConnectJiraView: View {
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
                    Button {
                        connect()
                    } label: {
                        HStack(spacing: 8) {
                            if isConnecting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.foreground)
                            }
                            Text("Se connecter avec Atlassian")
                        }
                    }
                    .buttonStyle(JiraPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(isConnecting || JiraOAuthConfiguration.bundled == nil)

                    if JiraOAuthConfiguration.bundled == nil {
                        Text("La configuration OAuth Atlassian est absente de cette version de l’app.")
                            .font(.paragraphS)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(width: 430)
            }
            .frame(width: 520)
        }
    }

    private func connect() {
        guard let configuration = JiraOAuthConfiguration.bundled else { return }
        onConnect(configuration)
    }
}
