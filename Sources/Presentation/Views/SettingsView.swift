import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(IssueFetchPreferences.storageKey) private var issueFetchLimit = IssueFetchPreferences.defaultLimit
    @State private var isConnecting = false
    @State private var resources: [JiraAccessibleResource] = []
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    settingsLabel("Jira OAuth")

                    Text("Connecte ton compte Atlassian pour synchroniser les sites Jira auxquels tu as accès.")
                        .font(.paragraphM)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            Task { await connect() }
                        } label: {
                            if isConnecting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Se connecter avec Atlassian")
                            }
                        }
                        .buttonStyle(JiraPrimaryButtonStyle(expandsToMaxWidth: false))
                        .disabled(isConnecting || JiraOAuthConfiguration.bundled == nil)

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

                VStack(alignment: .leading, spacing: 12) {
                    settingsLabel("Issues")

                    Picker("Nombre d’issues à charger", selection: $issueFetchLimit) {
                        ForEach(IssueFetchPreferences.availableLimits, id: \.self) { limit in
                            Text("\(limit)").tag(limit)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Les issues les plus récemment mises à jour seront chargées et affichées (200 maximum).")
                        .font(.paragraphS)
                        .foregroundStyle(.secondary)
                }
                .jiraPanel()

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
        .scrollClipDisabled()
        .frame(width: 520, height: 420)
        .task {
            loadConnectionState()
        }
        .onChange(of: issueFetchLimit) {
            NotificationCenter.default.post(name: .refreshRequested, object: nil)
        }
    }

    private func settingsLabel(_ value: String) -> some View {
        Text(value.uppercased())
            .font(.labelXS)
            .foregroundStyle(.secondary)
    }

    private func connect() async {
        guard let configuration = JiraOAuthConfiguration.bundled else {
            message = "La configuration OAuth Atlassian est absente de cette version de l’app."
            return
        }

        isConnecting = true
        message = nil
        defer { isConnecting = false }

        do {
            let result = try await container.jiraConnectionService.connect(configuration: configuration)

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
