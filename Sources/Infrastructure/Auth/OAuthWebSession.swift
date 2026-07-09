import AppKit
import Foundation

final class OAuthWebSession: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?

    func start(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                self.continuation = continuation
            }

            OAuthCallbackCenter.shared.register(scheme: callbackScheme) { [weak self] callbackURL in
                self?.finish(callbackURL: callbackURL, error: nil)
            }

            DispatchQueue.main.async {
                if !NSWorkspace.shared.open(url) {
                    self.finish(callbackURL: nil, error: AuthError.invalidServerResponse)
                }
            }
        }
    }

    private func finish(callbackURL: URL?, error: Error?) {
        let continuation = lock.withLock {
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }

        OAuthCallbackCenter.shared.unregister()

        guard let continuation else {
            return
        }

        if let error {
            continuation.resume(throwing: error)
            return
        }

        guard let callbackURL else {
            continuation.resume(throwing: AuthError.invalidServerResponse)
            return
        }

        continuation.resume(returning: callbackURL)
    }
}
