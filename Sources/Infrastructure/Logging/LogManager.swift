import Foundation
import OSLog

enum LogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var emoji: String {
        switch self {
        case .debug:
            "🟣"
        case .info:
            "🔵"
        case .warning:
            "🟡"
        case .error:
            "🔴"
        }
    }
}

/// Centralizes service telemetry and gives every service call a stable identifier and duration.
final class LogManager: @unchecked Sendable {
    static let shared = LogManager()

    struct Call: Sendable {
        fileprivate let id: UInt64
        fileprivate let service: String
        fileprivate let operation: String
        fileprivate let startedAt: ContinuousClock.Instant
        fileprivate let metadata: String
    }

    private let subsystem: String
    private let stateLock = NSLock()
    private var nextCallID: UInt64 = 0
    private var activeCallCount = 0

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "dev.matteofauchon.myjira") {
        self.subsystem = subsystem
    }

    @discardableResult
    func measure<T: Sendable>(
        service: String,
        operation: String,
        metadata: [String: String] = [:],
        _ body: () throws -> T
    ) throws -> T {
        let call = begin(service: service, operation: operation, metadata: metadata)
        do {
            let result = try body()
            finish(call, error: nil)
            return result
        } catch {
            finish(call, error: error)
            throw error
        }
    }

    @discardableResult
    func measure<T: Sendable>(
        service: String,
        operation: String,
        metadata: [String: String] = [:],
        _ body: () async throws -> T
    ) async throws -> T {
        let call = begin(service: service, operation: operation, metadata: metadata)
        do {
            let result = try await body()
            finish(call, error: nil)
            return result
        } catch {
            finish(call, error: error)
            throw error
        }
    }

    func measure(
        service: String,
        operation: String,
        metadata: [String: String] = [:],
        _ body: () async -> Bool
    ) async -> Bool {
        let call = begin(service: service, operation: operation, metadata: metadata)
        let result = await body()
        finish(call, error: nil)
        return result
    }

    private func begin(service: String, operation: String, metadata: [String: String]) -> Call {
        let state = withStateLock { () -> (UInt64, Int) in
            nextCallID += 1
            activeCallCount += 1
            return (nextCallID, activeCallCount)
        }
        let metadataText = Self.format(metadata: metadata)
        let logger = Logger(subsystem: subsystem, category: service)
        let signature = "\(service).\(operation)"
        log(
            level: .debug,
            logger: logger,
            "\(signature) #\(state.0) START | active=\(state.1)\(metadataText)"
        )
        return Call(
            id: state.0,
            service: service,
            operation: operation,
            startedAt: .now,
            metadata: metadataText
        )
    }

    private func finish(_ call: Call, error: Error?) {
        let active = withStateLock { () -> Int in
            activeCallCount = max(0, activeCallCount - 1)
            return activeCallCount
        }
        let duration = call.startedAt.duration(to: .now)
        let seconds = Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
        let logger = Logger(subsystem: subsystem, category: call.service)
        let durationText = String(format: "%.3f", seconds)
        let signature = "\(call.service).\(call.operation)"

        if let error {
            log(
                level: .error,
                logger: logger,
                "\(signature) #\(call.id) FAILURE | \(durationText)s | active=\(active) | error=\(String(describing: error))\(call.metadata)"
            )
        } else {
            log(
                level: .info,
                logger: logger,
                "\(signature) #\(call.id) SUCCESS | \(durationText)s | active=\(active)\(call.metadata)"
            )
        }
    }

    private func log(level: LogLevel, logger: Logger, _ message: String) {
        let logString = "\(level.emoji) [myJIRA] [\(level.rawValue)] \(message)"

        switch level {
        case .debug:
            logger.debug("\(logString, privacy: .public)")
        case .info:
            logger.info("\(logString, privacy: .public)")
        case .warning:
            logger.warning("\(logString, privacy: .public)")
        case .error:
            logger.fault("\(logString, privacy: .public)")
        }
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    private static func format(metadata: [String: String]) -> String {
        guard !metadata.isEmpty else { return "" }
        let fields = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        return " | \(fields)"
    }
}
