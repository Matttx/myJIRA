import Foundation

enum IssueFetchPreferences {
    static let storageKey = "issueFetchLimit"
    static let defaultLimit = 200
    static let maximumLimit = 200
    static let availableLimits = [25, 50, 100, 150, 200]

    static var limit: Int {
        let storedLimit = UserDefaults.standard.integer(forKey: storageKey)
        guard storedLimit > 0 else { return defaultLimit }
        return min(storedLimit, maximumLimit)
    }
}
