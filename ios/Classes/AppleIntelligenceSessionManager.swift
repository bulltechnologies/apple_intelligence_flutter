import Foundation
import FoundationModels

/// Manages a `LanguageModelSession` backing the Flutter method channel.
@available(iOS 26.0, *)
actor AppleIntelligenceSessionManager {
    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?
    private var storedInstructions: String?

    /// Prepares the session with optional developer-provided instructions.
    func configure(with instructions: String?) async throws -> SessionInitializationResult {
        storedInstructions = instructions?.sanitized()
        let availability = model.availability

        guard case .available = availability else {
            session = nil
            return SessionInitializationResult(availability: availability, sessionReady: false)
        }

        session = try makeSession()
        return SessionInitializationResult(availability: availability, sessionReady: true)
    }

    /// Returns the latest availability state without mutating the session.
    func availabilitySnapshot() -> SessionInitializationResult {
        SessionInitializationResult(availability: model.availability, sessionReady: session != nil)
    }

    /// Generates text using the stored session and most recent instructions.
    func generate(prompt: String, context: String?) async throws -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw AppleIntelligenceError.emptyPrompt
        }

        let availability = model.availability
        guard case .available = availability else {
            throw AppleIntelligenceError.unavailable(availability)
        }

        let activeSession = try session ?? makeSession()
        session = activeSession

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

        let response = try await activeSession.respond(to: constructedPrompt)
        return response.content
    }

    /// Streams text using the stored session and most recent instructions.
    func stream(prompt: String, context: String?) throws -> LanguageModelSession.ResponseStream<String> {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw AppleIntelligenceError.emptyPrompt
        }

        let availability = model.availability
        guard case .available = availability else {
            throw AppleIntelligenceError.unavailable(availability)
        }

        let activeSession = try session ?? makeSession()
        session = activeSession

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

        return activeSession.streamResponse(to: constructedPrompt)
    }

    /// Creates a new session honoring any stored instructions.
    private func makeSession() throws -> LanguageModelSession {
        if let instructions = storedInstructions {
            return try LanguageModelSession {
                instructions
            }
        }
        return try LanguageModelSession()
    }
}

/// Payload returned to Flutter callers after initialization/availability checks.
@available(iOS 26.0, *)
struct SessionInitializationResult {
    let availability: SystemLanguageModel.Availability
    let sessionReady: Bool

    func asDictionary() -> [String: Any] {
        var payload = availability.dictionaryRepresentation
        payload["sessionReady"] = sessionReady
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
