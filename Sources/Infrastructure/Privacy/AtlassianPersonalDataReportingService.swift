import Foundation

final class AtlassianPersonalDataReportingService: PersonalDataReportingService, @unchecked Sendable {
    private let authService: AuthService
    private let repository: PersonalDataRepository
    private let urlSession: URLSession
    private let now: @Sendable () -> Date

    init(
        authService: AuthService,
        repository: PersonalDataRepository,
        urlSession: URLSession = .shared,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.authService = authService
        self.repository = repository
        self.urlSession = urlSession
        self.now = now
    }

    @discardableResult
    func reportIfDue() async throws -> Bool {
        let reportDate = now()
        let accounts = try await repository.accountsDueForReporting(at: reportDate)
        guard !accounts.isEmpty else { return false }

        guard let accessToken = try await authService.validToken()?.accessToken else {
            throw PersonalDataReportingError.missingAccessToken
        }

        var erasedPersonalData = false
        for batch in accounts.chunked(maxCount: 90) {
            erasedPersonalData = try await report(
                batch: batch,
                accessToken: accessToken,
                reportDate: reportDate
            ) || erasedPersonalData
        }
        return erasedPersonalData
    }

    private func report(batch: [PersonalDataAccount], accessToken: String, reportDate: Date) async throws -> Bool {
        guard let endpoint = URL(string: "https://api.atlassian.com/app/report-accounts/") else {
            throw PersonalDataReportingError.invalidEndpoint
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(PersonalDataReportRequest(
            accounts: batch.map {
                PersonalDataReportRequest.Account(
                    accountID: $0.accountID,
                    updatedAt: $0.oldestRetrievedAt
                )
            }
        ))

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PersonalDataReportingError.invalidResponse
        }

        if httpResponse.statusCode == 429,
           let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After"),
           let retrySeconds = TimeInterval(retryAfter),
           retrySeconds > 0 {
            try await repository.scheduleNextReport(
                for: Set(batch.map(\.accountID)),
                at: reportDate.addingTimeInterval(retrySeconds)
            )
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            let message = String(data: data, encoding: .utf8) ?? "No response body"
            throw PersonalDataReportingError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let actions: [PersonalDataReportResponse.Account]
        if httpResponse.statusCode == 200 {
            actions = try JSONDecoder().decode(PersonalDataReportResponse.self, from: data).accounts
        } else {
            actions = []
        }

        let accountIDsToErase = Set(actions.compactMap { action -> String? in
            switch action.status {
            case "closed", "updated": action.accountID
            default: nil
            }
        })

        try await repository.erasePersonalData(for: accountIDsToErase)

        let reportedAccountIDs = Set(batch.map(\.accountID)).subtracting(accountIDsToErase)
        let nextReportAt = reportDate.addingTimeInterval(Self.cycleDuration(
            headerValue: httpResponse.value(forHTTPHeaderField: "Cycle-Period")
        ))
        try await repository.scheduleNextReport(for: reportedAccountIDs, at: nextReportAt)
        return !accountIDsToErase.isEmpty
    }

    private static func cycleDuration(headerValue: String?) -> TimeInterval {
        let defaultDuration = TimeInterval(7 * 24 * 60 * 60)
        guard let headerValue else { return defaultDuration }

        let trimmedValue = headerValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.hasPrefix("P"), trimmedValue.hasSuffix("D"),
           let days = Double(trimmedValue.dropFirst().dropLast()), days > 0 {
            return days * 24 * 60 * 60
        }

        guard let numericValue = Double(trimmedValue), numericValue > 0 else {
            return defaultDuration
        }

        // Atlassian describes the value as a cycle period but does not document
        // its unit. Accept both the commonly returned day count and seconds.
        return numericValue <= 365 ? numericValue * 24 * 60 * 60 : numericValue
    }
}

private struct PersonalDataReportRequest: Encodable {
    struct Account: Encodable {
        var accountID: String
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case accountID = "accountId"
            case updatedAt
        }
    }

    var accounts: [Account]
}

private struct PersonalDataReportResponse: Decodable {
    struct Account: Decodable {
        var accountID: String
        var status: String

        enum CodingKeys: String, CodingKey {
            case accountID = "accountId"
            case status
        }
    }

    var accounts: [Account]
}

private enum PersonalDataReportingError: LocalizedError {
    case missingAccessToken
    case invalidEndpoint
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            "A valid Atlassian access token is required for personal data reporting."
        case .invalidEndpoint:
            "The Atlassian personal data reporting endpoint is invalid."
        case .invalidResponse:
            "Atlassian returned an invalid personal data reporting response."
        case .requestFailed(let statusCode, let message):
            "Atlassian personal data reporting failed (HTTP \(statusCode)): \(message)"
        }
    }
}

private extension Array {
    func chunked(maxCount: Int) -> [[Element]] {
        guard maxCount > 0 else { return [] }
        return stride(from: 0, to: count, by: maxCount).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + maxCount, count)])
        }
    }
}
