import Foundation

struct PersonalDataAccount: Hashable, Sendable {
    var accountID: String
    var oldestRetrievedAt: Date
}
