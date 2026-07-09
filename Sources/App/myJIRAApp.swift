import AppKit
import SwiftUI

@main
struct MyJiraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container = AppContainer.live()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup("myJIRA", id: "main") {
            MainWindowView(
                viewModel: MainWindowViewModel(
                    workspaceRepository: container.workspaceRepository,
                    issueRepository: container.issueRepository,
                    syncService: container.syncService,
                    jiraConnectionService: container.jiraConnectionService
                ),
                router: router
            )
            .environment(container)
            .tint(.black)
            .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .refreshRequested, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environment(container)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        JiraFonts.registerIfNeeded()

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else {
            return
        }

        OAuthCallbackCenter.shared.handle(url: url)
        NSApp.activate(ignoringOtherApps: true)
    }
}
