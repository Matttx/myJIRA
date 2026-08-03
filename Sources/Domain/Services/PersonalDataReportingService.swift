protocol PersonalDataReportingService: Sendable {
    @discardableResult
    func reportIfDue() async throws -> Bool
}
