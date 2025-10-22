import Foundation
import FoundationModels

/// Manages `LanguageModelSession` instances backing the Flutter method channel.
@available(iOS 26.0, *)
actor AppleIntelligenceSessionManager {
    private struct SessionState {
        var instructions: String?
        var session: LanguageModelSession?
        var useCase: ManagedUseCase
    }

    private enum SessionIdentifier {
        static let `default` = "default"
    }

    private enum ManagedUseCase: String, CaseIterable, Sendable, Hashable {
        case general = "general"
        case contentTagging = "contentTagging"

        static func resolve(from identifier: String?, fallback: ManagedUseCase) throws -> ManagedUseCase {
            guard let identifier else {
                return fallback
            }

            let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return fallback
            }

            let normalized = ManagedUseCase.normalize(trimmed)
            switch normalized {
            case "general", "default":
                return .general
            case "contenttagging":
                return .contentTagging
            default:
                throw AppleIntelligenceError.invalidUseCase(
                    identifier,
                    supported: ManagedUseCase.supportedIdentifiers
                )
            }
        }

        private static func normalize(_ identifier: String) -> String {
            identifier
                .lowercased()
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")
        }

        private static var supportedIdentifiers: [String] {
            ManagedUseCase.allCases.map(\.rawValue)
        }

        var systemValue: SystemLanguageModel.UseCase {
            switch self {
            case .general:
                return .general
            case .contentTagging:
                return .contentTagging
            }
        }
    }

    private var sessions: [String: SessionState] = [:]
    private var cachedModels: [ManagedUseCase: SystemLanguageModel] = [:]

    /// Prepares the session with optional developer-provided instructions and use case.
    func configure(with instructions: String?, sessionId: String?, useCaseIdentifier: String?) async throws -> SessionInitializationResult {
        let identifier = sanitizeSessionIdentifier(sessionId)
        let sanitizedInstructions = instructions?.sanitized()

        let existingState = sessions[identifier]
        let fallbackUseCase = existingState?.useCase ?? .general
        let resolvedUseCase = try ManagedUseCase.resolve(from: useCaseIdentifier, fallback: fallbackUseCase)

        var state = existingState ?? SessionState(instructions: nil, session: nil, useCase: resolvedUseCase)
        state.instructions = sanitizedInstructions
        state.session = nil
        state.useCase = resolvedUseCase
        sessions[identifier] = state

        let model = resolveModel(for: resolvedUseCase)
        let availability = model.availability

        guard case .available = availability else {
            return SessionInitializationResult(
                availability: availability,
                sessionReady: false,
                sessionId: identifier,
                useCaseIdentifier: resolvedUseCase.rawValue
            )
        }

        let session = try makeSession(for: identifier)
        sessions[identifier]?.session = session

        return SessionInitializationResult(
            availability: availability,
            sessionReady: true,
            sessionId: identifier,
            useCaseIdentifier: resolvedUseCase.rawValue
        )
    }

    /// Returns the latest availability state without mutating the session.
    func availabilitySnapshot(sessionId: String?, useCaseIdentifier: String?) throws -> SessionInitializationResult {
        let identifier = sanitizeSessionIdentifier(sessionId)
        let state = sessions[identifier]
        let fallbackUseCase = state?.useCase ?? .general
        let useCase = try ManagedUseCase.resolve(from: useCaseIdentifier, fallback: fallbackUseCase)
        let model = resolveModel(for: useCase)
        return SessionInitializationResult(
            availability: model.availability,
            sessionReady: state?.session != nil,
            sessionId: identifier,
            useCaseIdentifier: useCase.rawValue
        )
    }

    /// Creates a new session with its own instructions and identifier.
    func createSession(with instructions: String?, useCaseIdentifier: String?) async throws -> SessionInitializationResult {
        let identifier = UUID().uuidString
        let sanitizedInstructions = instructions?.sanitized()

        let resolvedUseCase = try ManagedUseCase.resolve(from: useCaseIdentifier, fallback: .general)
        sessions[identifier] = SessionState(instructions: sanitizedInstructions, session: nil, useCase: resolvedUseCase)

        let model = resolveModel(for: resolvedUseCase)
        let availability = model.availability
        guard case .available = availability else {
            return SessionInitializationResult(
                availability: availability,
                sessionReady: false,
                sessionId: identifier,
                useCaseIdentifier: resolvedUseCase.rawValue
            )
        }

        let session = try makeSession(for: identifier)
        sessions[identifier]?.session = session
        return SessionInitializationResult(
            availability: availability,
            sessionReady: true,
            sessionId: identifier,
            useCaseIdentifier: resolvedUseCase.rawValue
        )
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

        let identifier = sanitizeSessionIdentifier(sessionId)
        let useCase = sessions[identifier]?.useCase ?? .general
        let model = resolveModel(for: useCase)
        let availability = model.availability
        guard case .available = availability else {
            throw AppleIntelligenceError.unavailable(availability)
        }

        let activeSession = try ensureSession(for: identifier, defaultUseCase: useCase)

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

        let identifier = sanitizeSessionIdentifier(sessionId)
        let useCase = sessions[identifier]?.useCase ?? .general
        let model = resolveModel(for: useCase)
        let availability = model.availability
        guard case .available = availability else {
            throw AppleIntelligenceError.unavailable(availability)
        }

        let activeSession = try ensureSession(for: identifier, defaultUseCase: useCase)

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
        guard let state = sessions[identifier] else {
            let model = resolveModel(for: .general)
            return try LanguageModelSession(model: model)
        }

        let model = resolveModel(for: state.useCase)
        if let instructions = state.instructions {
            return try LanguageModelSession(model: model) {
                instructions
            }
        }

        return try LanguageModelSession(model: model)
    }

    private func ensureSession(for identifier: String, defaultUseCase: ManagedUseCase) throws -> LanguageModelSession {
        if let existing = sessions[identifier]?.session {
            return existing
        }

        if sessions[identifier] == nil {
            sessions[identifier] = SessionState(instructions: nil, session: nil, useCase: defaultUseCase)
        }

        let session = try makeSession(for: identifier)
        sessions[identifier]?.session = session
        return session
    }

    private func resolveModel(for useCase: ManagedUseCase) -> SystemLanguageModel {
        if let cached = cachedModels[useCase] {
            return cached
        }

        let model: SystemLanguageModel
        switch useCase {
        case .general:
            model = SystemLanguageModel.default
        case .contentTagging:
            model = SystemLanguageModel(useCase: .contentTagging)
        }

        cachedModels[useCase] = model
        return model
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
    let useCaseIdentifier: String

    func asDictionary() -> [String: Any] {
        var payload = availability.dictionaryRepresentation
        payload["sessionReady"] = sessionReady
        payload["sessionId"] = sessionId
        payload["useCase"] = useCaseIdentifier
        return payload
    }
}

/// Errors specific to the Flutter <> FoundationModels integration layer.
@available(iOS 26.0, *)
enum AppleIntelligenceError: Error {
    case emptyPrompt
    case unavailable(SystemLanguageModel.Availability)
    case invalidUseCase(String, supported: [String])
}

@available(iOS 26.0, *)
extension AppleIntelligenceError {
    var code: String {
        switch self {
        case .emptyPrompt:
            return "empty_prompt"
        case .unavailable:
            return "unavailable"
        case .invalidUseCase:
            return "invalid_use_case"
        }
    }

    var message: String {
        switch self {
        case .emptyPrompt:
            return "The prompt must contain non-whitespace characters."
        case .unavailable(let availability):
            return availability.humanReadableReason
        case .invalidUseCase(let provided, _):
            return "Unsupported use case '\(provided)'."
        }
    }

    var details: Any? {
        switch self {
        case .emptyPrompt:
            return nil
        case .unavailable(let availability):
            return availability.dictionaryRepresentation
        case .invalidUseCase(let provided, let supported):
            return [
                "providedUseCase": provided,
                "supportedUseCases": supported
            ]
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
