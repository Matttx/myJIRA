import Foundation

final class OAuthCallbackCenter: @unchecked Sendable {
    static let shared = OAuthCallbackCenter()

    private let lock = NSLock()
    private var expectedScheme: String?
    private var callback: ((URL) -> Void)?

    private init() {}

    func register(scheme: String, callback: @escaping (URL) -> Void) {
        lock.withLock {
            expectedScheme = scheme
            self.callback = callback
        }
    }

    func unregister() {
        lock.withLock {
            expectedScheme = nil
            callback = nil
        }
    }

    func handle(url: URL) {
        let callback = lock.withLock {
            guard url.scheme == expectedScheme else {
                return nil as ((URL) -> Void)?
            }

            return self.callback
        }

        callback?(url)
    }
}
