import Foundation
import FoundationModels

/// Manages `LanguageModelSession` instances backing the Flutter method channel.
@available(iOS 26.0, *)
actor AppleIntelligenceSessionManager {
    private struct SessionState {
        var instructions: String?
        var session: LanguageModelSession?
    }

    private enum SessionIdentifier {
        static let `default` = "default"
    }

    private let model = SystemLanguageModel.default
    private var sessions: [String: SessionState] = [:]

    /// Prepares the session with optional developer-provided instructions.
    func configure(with instructions: String?, sessionId: String?) async throws -> SessionInitializationResult {
        let identifier = sanitizeSessionIdentifier(sessionId)
        let sanitizedInstructions = instructions?.sanitized()

        var state = sessions[identifier] ?? SessionState()
        state.instructions = sanitizedInstructions
        state.session = nil
        sessions[identifier] = state

        let availability = model.availability

        guard case .available = availability else {
            return SessionInitializationResult(availability: availability, sessionReady: false, sessionId: identifier)
        }

        let session = try makeSession(for: identifier)
        sessions[identifier]?.session = session

        return SessionInitializationResult(availability: availability, sessionReady: true, sessionId: identifier)
    }

    /// Returns the latest availability state without mutating the session.
    func availabilitySnapshot(sessionId: String?) -> SessionInitializationResult {
        let identifier = sanitizeSessionIdentifier(sessionId)
        let state = sessions[identifier]
        return SessionInitializationResult(
            availability: model.availability,
            sessionReady: state?.session != nil,
            sessionId: identifier
        )
    }

    /// Creates a new session with its own instructions and identifier.
    func createSession(with instructions: String?) async throws -> SessionInitializationResult {
        let identifier = UUID().uuidString
        let sanitizedInstructions = instructions?.sanitized()
        sessions[identifier] = SessionState(instructions: sanitizedInstructions, session: nil)

        let availability = model.availability
        guard case .available = availability else {
            return SessionInitializationResult(availability: availability, sessionReady: false, sessionId: identifier)
        }

        let session = try makeSession(for: identifier)
        sessions[identifier]?.session = session
        return SessionInitializationResult(availability: availability, sessionReady: true, sessionId: identifier)
    }

    /// Tears down a previously created session.
    func closeSession(with identifier: String) {
        sessions[identifier] = nil
    }

    /// Generates text using the stored session and most recent instructions.
    func generate(prompt: String, context: String?, sessionId: String?, options: GenerationOptions?) async throws -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw AppleIntelligenceError.emptyPrompt
        }

        let availability = model.availability
        guard case .available = availability else {
            throw AppleIntelligenceError.unavailable(availability)
        }

        let identifier = sanitizeSessionIdentifier(sessionId)
        let activeSession = try ensureSession(for: identifier)

        let trimmedContext = context?.sanitized()
        let constructedPrompt: Prompt
        if let trimmedContext {
            constructedPrompt = Prompt {
                trimmedContext
                trimmedPrompt
            }
        } else {
            constructedPrompt = Prompt(trimmedPrompt)
        }

        let response: LanguageModelSession.Response<String>
        if let options {
            response = try await activeSession.respond(to: constructedPrompt, options: options)
        } else {
            response = try await activeSession.respond(to: constructedPrompt)
        }
        return response.content
    }

    /// Streams text using the stored session and most recent instructions.
    func stream(prompt: String, context: String?, sessionId: String?, options: GenerationOptions?) throws -> LanguageModelSession.ResponseStream<String> {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw AppleIntelligenceError.emptyPrompt
        }

        let availability = model.availability
        guard case .available = availability else {
            throw AppleIntelligenceError.unavailable(availability)
        }

        let identifier = sanitizeSessionIdentifier(sessionId)
        let activeSession = try ensureSession(for: identifier)

        let trimmedContext = context?.sanitized()
        let constructedPrompt: Prompt
        if let trimmedContext {
            constructedPrompt = Prompt {
                trimmedContext
                trimmedPrompt
            }
        } else {
            constructedPrompt = Prompt(trimmedPrompt)
        }

        if let options {
            return activeSession.streamResponse(to: constructedPrompt, options: options)
        }
        return activeSession.streamResponse(to: constructedPrompt)
    }

    /// Creates a new session honoring any stored instructions.
    private func makeSession(for identifier: String) throws -> LanguageModelSession {
        guard let instructions = sessions[identifier]?.instructions else {
            return try LanguageModelSession()
        }

        return try LanguageModelSession {
            instructions
        }
    }

    private func ensureSession(for identifier: String) throws -> LanguageModelSession {
        if let existing = sessions[identifier]?.session {
            return existing
        }

        let session = try makeSession(for: identifier)
        if sessions[identifier] == nil {
            sessions[identifier] = SessionState(instructions: nil, session: session)
        } else {
            sessions[identifier]?.session = session
        }
        return session
    }

    private func sanitizeSessionIdentifier(_ provided: String?) -> String {
        guard let provided, !provided.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SessionIdentifier.default
        }
        return provided
    }
}

/// Payload returned to Flutter callers after initialization/availability checks.
@available(iOS 26.0, *)
struct SessionInitializationResult {
    let availability: SystemLanguageModel.Availability
    let sessionReady: Bool
    let sessionId: String

    func asDictionary() -> [String: Any] {
        var payload = availability.dictionaryRepresentation
        payload["sessionReady"] = sessionReady
        payload["sessionId"] = sessionId
        return payload
    }
}

/// Errors specific to the Flutter <> FoundationModels integration layer.
@available(iOS 26.0, *)
enum AppleIntelligenceError: Error {
    case emptyPrompt
    case unavailable(SystemLanguageModel.Availability)
}

@available(iOS 26.0, *)
extension AppleIntelligenceError {
    var code: String {
        switch self {
        case .emptyPrompt:
            return "empty_prompt"
        case .unavailable:
            return "unavailable"
        }
    }

    var message: String {
        switch self {
        case .emptyPrompt:
            return "The prompt must contain non-whitespace characters."
        case .unavailable(let availability):
            return availability.humanReadableReason
        }
    }

    var details: Any? {
        switch self {
        case .emptyPrompt:
            return nil
        case .unavailable(let availability):
            return availability.dictionaryRepresentation
        }
    }
}

@available(iOS 26.0, *)
extension SystemLanguageModel.Availability {
    var dictionaryRepresentation: [String: Any] {
        switch self {
        case .available:
            return [
                "available": true,
                "code": "available"
            ]
        case .unavailable(let reason):
            return [
                "available": false,
                "code": reason.code,
                "reason": reason.message
            ]
        }
    }

    var humanReadableReason: String {
        switch self {
        case .available:
            return "Apple Intelligence is available."
        case .unavailable(let reason):
            return reason.message
        }
    }
}

@available(iOS 26.0, *)
extension SystemLanguageModel.Availability.UnavailableReason {
    var code: String {
        switch self {
        case .appleIntelligenceNotEnabled:
            return "apple_intelligence_not_enabled"
        case .deviceNotEligible:
            return "device_not_eligible"
        case .modelNotReady:
            return "model_not_ready"
        @unknown default:
            return "unknown"
        }
    }

    var message: String {
        switch self {
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled on this device."
        case .deviceNotEligible:
            return "This device does not meet the requirements for Apple Intelligence."
        case .modelNotReady:
            return "The Apple Intelligence model is downloading or otherwise not ready yet."
        @unknown default:
            return "Apple Intelligence is unavailable for an unknown reason."
        }
    }
}

private extension String {
    /// Trims whitespace/newlines and ensures the returned value is non-empty.
    func sanitized() -> String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
