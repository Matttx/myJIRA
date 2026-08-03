import Foundation

protocol PersonalDataRepository: Sendable {
    func accountsDueForReporting(at date: Date) async throws -> [PersonalDataAccount]
    func scheduleNextReport(for accountIDs: Set<String>, at date: Date) async throws
    func erasePersonalData(for accountIDs: Set<String>) async throws
}
