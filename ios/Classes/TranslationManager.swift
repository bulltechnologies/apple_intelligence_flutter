import Foundation
import Translation

@available(iOS 26.0, *)
enum TranslationManagerError: Error {
    case emptyText
    case invalidLanguageIdentifier(String)
    case noResponse
}

@available(iOS 26.0, *)
extension TranslationManagerError: LocalizedError {
    var code: String {
        switch self {
        case .emptyText:
            return "translation_empty_text"
        case .invalidLanguageIdentifier:
            return "translation_invalid_language"
        case .noResponse:
            return "translation_no_response"
        }
    }

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Text to translate must not be empty."
        case .invalidLanguageIdentifier(let identifier):
            return "The language identifier '\(identifier)' is invalid."
        case .noResponse:
            return "Translation did not return a response."
        }
    }

    var failureReason: String? {
        switch self {
        case .emptyText:
            return "The provided text only contained whitespace characters."
        case .invalidLanguageIdentifier:
            return nil
        case .noResponse:
            return "TranslationSession returned an empty response array."
        }
    }

    var errorDetails: [String: Any]? {
        switch self {
        case .invalidLanguageIdentifier(let identifier):
            return ["identifier": identifier]
        default:
            return nil
        }
    }
}

@available(iOS 26.0, *)
struct TranslationResponsePayload {
    let sourceText: String
    let targetText: String
    let sourceLanguage: String?
    let targetLanguage: String?
    let clientIdentifier: String?

    init(response: TranslationSession.Response) {
        sourceText = response.sourceText
        targetText = response.targetText
        sourceLanguage = response.sourceLanguage?.minimalIdentifier
        targetLanguage = response.targetLanguage?.minimalIdentifier
        clientIdentifier = response.clientIdentifier
    }

    func asDictionary() -> [String: Any] {
        var payload: [String: Any] = [
            "sourceText": sourceText,
            "targetText": targetText
        ]

        if let sourceLanguage {
            payload["sourceLanguage"] = sourceLanguage
        }
        if let targetLanguage {
            payload["targetLanguage"] = targetLanguage
        }
        if let clientIdentifier, !clientIdentifier.isEmpty {
            payload["clientIdentifier"] = clientIdentifier
        }

        return payload
    }
}

@available(iOS 26.0, *)
struct TranslationAvailabilityPayload {
    let status: String
    let isInstalled: Bool
    let isSupported: Bool
    let sourceLanguage: String
    let targetLanguage: String?

    func asDictionary() -> [String: Any] {
        var payload: [String: Any] = [
            "status": status,
            "isInstalled": isInstalled,
            "isSupported": isSupported,
            "sourceLanguage": sourceLanguage
        ]

        if let targetLanguage {
            payload["targetLanguage"] = targetLanguage
        }

        return payload
    }
}

@available(iOS 26.0, *)
actor TranslationManager {
    static let shared = TranslationManager()

    private struct SessionKey: Hashable {
        let source: String
        let target: String?
    }

    private var sessions: [SessionKey: TranslationSession] = [:]
    private let availability = LanguageAvailability()

    func translate(
        text: String,
        source: Locale.Language,
        target: Locale.Language?,
        clientIdentifier: String?
    ) async throws -> TranslationResponsePayload {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationManagerError.emptyText
        }

        let session = try sessionFor(source: source, target: target)
        let request = TranslationSession.Request(
            sourceText: trimmed,
            clientIdentifier: clientIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let responses = try await session.translations(from: [request])
        guard let first = responses.first else {
            throw TranslationManagerError.noResponse
        }

        return TranslationResponsePayload(response: first)
    }

    func prepareTranslation(source: Locale.Language, target: Locale.Language?) async throws {
        let session = try sessionFor(source: source, target: target)
        try await session.prepareTranslation()
    }

    func availabilityStatus(source: Locale.Language, target: Locale.Language?) async -> TranslationAvailabilityPayload {
        let status = await availability.status(from: source, to: target)
        let statusString: String
        let isInstalled: Bool
        switch status {
        case .installed:
            statusString = "installed"
            isInstalled = true
        case .supported:
            statusString = "supported"
            isInstalled = false
        case .unsupported:
            statusString = "unsupported"
            isInstalled = false
        @unknown default:
            statusString = "unknown"
            isInstalled = false
        }

        let isSupported = status != .unsupported
        return TranslationAvailabilityPayload(
            status: statusString,
            isInstalled: isInstalled,
            isSupported: isSupported,
            sourceLanguage: source.minimalIdentifier,
            targetLanguage: target?.minimalIdentifier
        )
    }

    func supportedLanguageIdentifiers() -> [String] {
        availability.supportedLanguages.map { $0.minimalIdentifier }
    }

    private func sessionFor(source: Locale.Language, target: Locale.Language?) throws -> TranslationSession {
        let key = SessionKey(
            source: source.minimalIdentifier,
            target: target?.minimalIdentifier
        )

        if let existing = sessions[key], existing.isReady {
            return existing
        }

        let session = try TranslationSession(installedSource: source, target: target)
        sessions[key] = session
        return session
    }
}

@available(iOS 26.0, *)
func makeLanguage(from identifier: String) throws -> Locale.Language {
    let raw = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else {
        throw TranslationManagerError.invalidLanguageIdentifier(identifier)
    }
    return Locale.Language(identifier: raw)
}

@available(iOS 26.0, *)
func makeOptionalLanguage(from identifier: String?) throws -> Locale.Language? {
    guard let identifier else {
        return nil
    }
    let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return nil
    }
    return Locale.Language(identifier: trimmed)
}

@available(iOS 26.0, *)
func translationErrorCode(from error: TranslationError) -> String {
    let mirror = Mirror(reflecting: error)
    for child in mirror.children {
        if child.label == "cause" {
            let description = String(describing: child.value)
            return "translation_\(description)"
        }
    }
    return "translation_error"
}

@available(iOS 26.0, *)
func translationErrorDetails(from error: TranslationError) -> [String: Any]? {
    [
        "description": String(describing: error)
    ]
}
