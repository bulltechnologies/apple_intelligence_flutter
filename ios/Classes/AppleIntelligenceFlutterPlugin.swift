import Flutter
import Foundation
import FoundationModels
import Translation

/// Flutter plugin that bridges Apple Intelligence Foundation Models to Dart.
public class AppleIntelligenceFlutterPlugin: NSObject, FlutterPlugin {
    private var sessionManager: Any?
    private var streamHandler: Any?

    /// Registers the plugin and installs the method channel handler.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "apple_intelligence_flutter", binaryMessenger: registrar.messenger())
        let instance = AppleIntelligenceFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let streamChannel = FlutterEventChannel(name: "apple_intelligence_flutter/stream", binaryMessenger: registrar.messenger())
        if #available(iOS 26.0, *) {
            let handler = AppleIntelligenceStreamHandler(plugin: instance)
            streamChannel.setStreamHandler(handler)
            instance.streamHandler = handler
        } else {
            streamChannel.setStreamHandler(UnsupportedStreamHandler())
        }
    }

    /// Dispatches incoming method channel calls.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call.arguments, result: result)
        case "isAvailable":
            handleIsAvailable(call.arguments, result: result)
        case "sendPrompt":
            handleSendPrompt(call.arguments, result: result)
        case "createSession":
            handleCreateSession(call.arguments, result: result)
        case "closeSession":
            handleCloseSession(call.arguments, result: result)
        case "transcribeAudio":
            handleTranscribeAudio(call.arguments, result: result)
        case "translateText":
            handleTranslateText(call.arguments, result: result)
        case "translationSupportedLanguages":
            handleTranslationSupportedLanguages(result: result)
        case "translationAvailability":
            handleTranslationAvailability(call.arguments, result: result)
        case "prepareTranslation":
            handlePrepareTranslation(call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Handles initialization and instructions configuration.
    private func handleInitialize(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedFoundationModelsPayload())
            return
        }

        let instructions = (arguments as? [String: Any])?["instructions"] as? String
        let sessionId = (arguments as? [String: Any])?["sessionId"] as? String

        Task {
            do {
                let manager = resolveSessionManager()
                let initResult = try await manager.configure(with: instructions, sessionId: sessionId)
                DispatchQueue.main.async {
                    result(initResult.asDictionary())
                }
            } catch {
                DispatchQueue.main.async {
                    result(self.makeFlutterError(from: error))
                }
            }
        }
    }

    /// Returns the current availability snapshot to Dart.
    private func handleIsAvailable(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedFoundationModelsPayload())
            return
        }

        Task {
            let manager = resolveSessionManager()
            let sessionId = (arguments as? [String: Any])?["sessionId"] as? String
            let snapshot = await manager.availabilitySnapshot(sessionId: sessionId)
            DispatchQueue.main.async {
                result(snapshot.asDictionary())
            }
        }
    }

    /// Performs generation using the managed `LanguageModelSession`.
    private func handleSendPrompt(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedFoundationModelsError())
            return
        }

        guard let params = arguments as? [String: Any], let prompt = params["prompt"] as? String else {
            result(FlutterError(code: "invalid_arguments", message: "A non-empty 'prompt' string is required.", details: nil))
            return
        }

        let context = params["context"] as? String
        let sessionId = params["sessionId"] as? String
        let optionsRaw = params["options"]
        let options: GenerationOptions?
        do {
            options = try parseGenerationOptions(from: optionsRaw)
        } catch let error as GenerationOptionsParsingError {
            result(error.flutterError)
            return
        } catch {
            result(self.makeFlutterError(from: error))
            return
        }

        Task {
            do {
                let manager = resolveSessionManager()
                let response = try await manager.generate(prompt: prompt, context: context, sessionId: sessionId, options: options)
                DispatchQueue.main.async {
                    result(response)
                }
            } catch {
                DispatchQueue.main.async {
                    result(self.makeFlutterError(from: error))
                }
            }
        }
    }

    private func handleCreateSession(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedFoundationModelsPayload())
            return
        }

        let instructions = (arguments as? [String: Any])?["instructions"] as? String

        Task {
            do {
                let manager = resolveSessionManager()
                let initResult = try await manager.createSession(with: instructions)
                DispatchQueue.main.async {
                    result(initResult.asDictionary())
                }
            } catch {
                DispatchQueue.main.async {
                    result(self.makeFlutterError(from: error))
                }
            }
        }
    }

    private func handleCloseSession(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedFoundationModelsPayload())
            return
        }

        guard
            let params = arguments as? [String: Any],
            let sessionId = params["sessionId"] as? String,
            !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            result(FlutterError(
                code: "invalid_arguments",
                message: "Parameter 'sessionId' is required.",
                details: nil
            ))
            return
        }

        let manager = resolveSessionManager()
        Task {
            await manager.closeSession(with: sessionId)
            DispatchQueue.main.async {
                result(nil)
            }
        }
    }

    private func handleTranscribeAudio(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 15.0, *) else {
            result(FlutterError(code: "unsupported_platform", message: "Speech recognition requires iOS 15.0 or newer.", details: nil))
            return
        }

#if canImport(Speech)
        SpeechTranscriptionManager.handleTranscribeAudio(
            arguments,
            result: result,
            errorMapper: { [weak self] error in
                guard let self else {
                    return FlutterError(
                        code: "apple_intelligence_error",
                        message: error.localizedDescription,
                        details: nil
                    )
                }
                return self.makeFlutterError(from: error)
            }
        )
#else
        result(FlutterError(code: "unsupported_platform", message: "Speech framework unavailable on this platform.", details: nil))
#endif
    }

    private func handleTranslateText(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedTranslationError())
            return
        }

        guard
            let params = arguments as? [String: Any],
            let text = params["text"] as? String,
            let sourceIdentifier = params["sourceLanguage"] as? String,
            let targetIdentifier = params["targetLanguage"] as? String
        else {
            result(FlutterError(
                code: "invalid_arguments",
                message: "Parameters 'text', 'sourceLanguage', and 'targetLanguage' are required.",
                details: nil
            ))
            return
        }

        let clientIdentifier = params["clientIdentifier"] as? String
        handleTranslateTextAvailable(
            text: text,
            sourceIdentifier: sourceIdentifier,
            targetIdentifier: targetIdentifier,
            clientIdentifier: clientIdentifier,
            result: result
        )
    }

    private func handleTranslationSupportedLanguages(result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedTranslationError())
            return
        }

        handleTranslationSupportedLanguagesAvailable(result: result)
    }

    private func handleTranslationAvailability(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedTranslationError())
            return
        }

        guard
            let params = arguments as? [String: Any],
            let sourceIdentifier = params["sourceLanguage"] as? String
        else {
            result(FlutterError(
                code: "invalid_arguments",
                message: "Parameter 'sourceLanguage' is required.",
                details: nil
            ))
            return
        }

        let targetIdentifier = params["targetLanguage"] as? String
        handleTranslationAvailabilityAvailable(
            sourceIdentifier: sourceIdentifier,
            targetIdentifier: targetIdentifier,
            result: result
        )
    }

    private func handlePrepareTranslation(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedTranslationError())
            return
        }

        guard
            let params = arguments as? [String: Any],
            let sourceIdentifier = params["sourceLanguage"] as? String
        else {
            result(FlutterError(
                code: "invalid_arguments",
                message: "Parameter 'sourceLanguage' is required.",
                details: nil
            ))
            return
        }

        let targetIdentifier = params["targetLanguage"] as? String
        handlePrepareTranslationAvailable(
            sourceIdentifier: sourceIdentifier,
            targetIdentifier: targetIdentifier,
            result: result
        )
    }

    @available(iOS 26.0, *)
    fileprivate func resolveSessionManager() -> AppleIntelligenceSessionManager {
        if let manager = sessionManager as? AppleIntelligenceSessionManager {
            return manager
        }
        let manager = AppleIntelligenceSessionManager()
        sessionManager = manager
        return manager
    }

    /// Convenience payload used when the running platform cannot host Apple Intelligence.
    private func unsupportedFoundationModelsPayload() -> [String: Any] {
        [
            "available": false,
            "code": "unsupported_platform",
            "reason": "Apple Intelligence requires iOS 26.0 or newer."
        ]
    }

    /// Convenience error returned to Flutter when the platform is unsupported.
    private func unsupportedFoundationModelsError() -> FlutterError {
        FlutterError(code: "unsupported_platform", message: "Apple Intelligence requires iOS 26.0 or newer.", details: nil)
    }

    /// Convenience error returned when Translation framework features aren't available.
    private func unsupportedTranslationError() -> FlutterError {
        FlutterError(code: "unsupported_platform", message: "Apple Translation requires iOS 26.0 or newer.", details: nil)
    }

    /// Normalizes native errors into Flutter-friendly payloads.
    fileprivate func makeFlutterError(from error: Error) -> FlutterError {
        if #available(iOS 26.0, *), let aiError = error as? AppleIntelligenceError {
            return FlutterError(code: aiError.code, message: aiError.message, details: aiError.details)
        }

        if #available(iOS 26.0, *), let generationError = error as? LanguageModelSession.GenerationError {
            let details = sanitizedDetails([
                "failureReason": generationError.failureReason,
                "recoverySuggestion": generationError.recoverySuggestion
            ])

            return FlutterError(
                code: "generation_error",
                message: generationError.errorDescription ?? "Apple Intelligence failed to generate a response.",
                details: details
            )
        }

        if #available(iOS 26.0, *), let translationError = error as? TranslationError {
            return makeTranslationFlutterError(from: translationError)
        }

        if let localized = error as? LocalizedError {
            let details = sanitizedDetails([
                "failureReason": localized.failureReason,
                "recoverySuggestion": localized.recoverySuggestion
            ])
            return FlutterError(
                code: "apple_intelligence_error",
                message: localized.errorDescription ?? String(describing: error),
                details: details
            )
        }

        let nsError = error as NSError
        let details = [
            "domain": nsError.domain,
            "code": nsError.code
        ] as [String: Any]
        return FlutterError(
            code: "apple_intelligence_error",
            message: nsError.localizedDescription,
            details: details
        )
    }

    @available(iOS 26.0, *)
    private func makeTranslationFlutterError(from error: TranslationError) -> FlutterError {
        let code: String
        switch error {
        case TranslationError.nothingToTranslate:
            code = "translation_nothing_to_translate"
        case TranslationError.unableToIdentifyLanguage:
            code = "translation_unable_to_identify_language"
        case TranslationError.internalError:
            code = "translation_internal_error"
        case TranslationError.alreadyCancelled:
            code = "translation_already_cancelled"
        case TranslationError.notInstalled:
            code = "translation_not_installed"
        case TranslationError.unsupportedSourceLanguage:
            code = "translation_unsupported_source_language"
        case TranslationError.unsupportedTargetLanguage:
            code = "translation_unsupported_target_language"
        case TranslationError.unsupportedLanguagePairing:
            code = "translation_unsupported_language_pairing"
        default:
            code = "translation_error"
        }

        let details = sanitizedDetails([
            "failureReason": error.failureReason,
            "recoverySuggestion": error.recoverySuggestion
        ])

        return FlutterError(
            code: code,
            message: error.errorDescription ?? error.localizedDescription,
            details: details
        )
    }

    /// Removes nil values from an error-details dictionary.
    private func sanitizedDetails(_ dictionary: [String: Any?]) -> [String: Any]? {
        let filtered = dictionary.compactMapValues { $0 }
        return filtered.isEmpty ? nil : filtered
    }
}

@available(iOS 26.0, *)
fileprivate enum GenerationOptionsParsingError: Error {
    case invalid(String)

    var flutterError: FlutterError {
        switch self {
        case .invalid(let message):
            return FlutterError(code: "invalid_generation_options", message: message, details: nil)
        }
    }
}

@available(iOS 26.0, *)
fileprivate func parseGenerationOptions(from raw: Any?) throws -> GenerationOptions? {
    guard let raw else { return nil }
    guard let dict = raw as? [String: Any] else {
        throw GenerationOptionsParsingError.invalid("Generation options must be provided as a map of values.")
    }

    let temperature = try castOptionalDouble(dict["temperature"], label: "temperature")
    let maximumTokens = try castOptionalInt(dict["maximumResponseTokens"], label: "maximumResponseTokens")

    var samplingMode: GenerationOptions.SamplingMode?
    if let samplingRaw = dict["samplingMode"] {
        guard let samplingDict = samplingRaw as? [String: Any] else {
            throw GenerationOptionsParsingError.invalid("samplingMode must be a map with a 'type' field.")
        }
        guard let typeValue = (samplingDict["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !typeValue.isEmpty else {
            throw GenerationOptionsParsingError.invalid("samplingMode requires a non-empty 'type'.")
        }

        switch typeValue {
        case "greedy":
            samplingMode = .greedy
        case "randomtop", "randomtopk", "topk":
            let top = try castRequiredInt(samplingDict["top"], label: "samplingMode.top")
            guard top > 0 else {
                throw GenerationOptionsParsingError.invalid("samplingMode.top must be greater than zero.")
            }
            let seed = try castOptionalUInt64(samplingDict["seed"], label: "samplingMode.seed")
            samplingMode = .random(top: top, seed: seed)
        case "randomprobability", "topp", "nucleus":
            let threshold = try castRequiredDouble(samplingDict["probabilityThreshold"], label: "samplingMode.probabilityThreshold")
            guard threshold >= 0.0, threshold <= 1.0 else {
                throw GenerationOptionsParsingError.invalid("samplingMode.probabilityThreshold must be between 0.0 and 1.0.")
            }
            let seed = try castOptionalUInt64(samplingDict["seed"], label: "samplingMode.seed")
            samplingMode = .random(probabilityThreshold: threshold, seed: seed)
        default:
            throw GenerationOptionsParsingError.invalid("Unknown samplingMode type '\(typeValue)'.")
        }
    }

    if let maximumTokens, maximumTokens <= 0 {
        throw GenerationOptionsParsingError.invalid("maximumResponseTokens must be greater than zero when provided.")
    }

    if temperature != nil || maximumTokens != nil || samplingMode != nil {
        return GenerationOptions(
            sampling: samplingMode,
            temperature: temperature,
            maximumResponseTokens: maximumTokens
        )
    }

    return nil
}

@available(iOS 26.0, *)
fileprivate func castOptionalDouble(_ value: Any?, label: String) throws -> Double? {
    guard let value else { return nil }
    if let number = value as? NSNumber {
        return number.doubleValue
    }
    if let double = value as? Double {
        return double
    }
    if let string = value as? String, let parsed = Double(string) {
        return parsed
    }
    throw GenerationOptionsParsingError.invalid("Generation option '\(label)' must be a floating point number.")
}

@available(iOS 26.0, *)
fileprivate func castOptionalInt(_ value: Any?, label: String) throws -> Int? {
    guard let value else { return nil }
    if let number = value as? NSNumber {
        return number.intValue
    }
    if let intValue = value as? Int {
        return intValue
    }
    if let string = value as? String, let parsed = Int(string) {
        return parsed
    }
    throw GenerationOptionsParsingError.invalid("Generation option '\(label)' must be an integer.")
}

@available(iOS 26.0, *)
fileprivate func castRequiredInt(_ value: Any?, label: String) throws -> Int {
    if let parsed = try castOptionalInt(value, label: label) {
        return parsed
    }
    throw GenerationOptionsParsingError.invalid("Generation option '\(label)' is required.")
}

@available(iOS 26.0, *)
fileprivate func castRequiredDouble(_ value: Any?, label: String) throws -> Double {
    if let parsed = try castOptionalDouble(value, label: label) {
        return parsed
    }
    throw GenerationOptionsParsingError.invalid("Generation option '\(label)' is required.")
}

@available(iOS 26.0, *)
fileprivate func castOptionalUInt64(_ value: Any?, label: String) throws -> UInt64? {
    guard let value else { return nil }
    if let number = value as? NSNumber {
        let doubleValue = number.doubleValue
        guard doubleValue >= 0 else {
            throw GenerationOptionsParsingError.invalid("Generation option '\(label)' must be non-negative.")
        }
        return number.uint64Value
    }
    if let uintValue = value as? UInt64 {
        return uintValue
    }
    if let intValue = value as? Int {
        guard intValue >= 0 else {
            throw GenerationOptionsParsingError.invalid("Generation option '\(label)' must be non-negative.")
        }
        return UInt64(intValue)
    }
    if let string = value as? String, let parsed = UInt64(string) {
        return parsed
    }
    throw GenerationOptionsParsingError.invalid("Generation option '\(label)' must be a non-negative integer.")
}

@available(iOS 26.0, *)
private extension AppleIntelligenceFlutterPlugin {
    func handleTranslateTextAvailable(
        text: String,
        sourceIdentifier: String,
        targetIdentifier: String,
        clientIdentifier: String?,
        result: @escaping FlutterResult
    ) {
        Task {
            do {
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedText.isEmpty else {
                    throw TranslationError.nothingToTranslate
                }

                let sourceLanguage = try language(from: sourceIdentifier)
                let targetLanguage = try language(from: targetIdentifier)
                let session = try TranslationSession(installedSource: sourceLanguage, target: targetLanguage)

                let request = TranslationSession.Request(
                    sourceText: trimmedText,
                    clientIdentifier: normalizedClientIdentifier(clientIdentifier)
                )

                let responses = try await session.translations(from: [request])
                guard let response = responses.first else {
                    throw TranslationError.internalError
                }

                let payload = translationResponseDictionary(from: response)
                DispatchQueue.main.async {
                    result(payload)
                }
            } catch {
                DispatchQueue.main.async {
                    result(self.makeFlutterError(from: error))
                }
            }
        }
    }

    func handleTranslationSupportedLanguagesAvailable(result: @escaping FlutterResult) {
        Task {
            let availability = LanguageAvailability()
            let languages = await availability.supportedLanguages
            let identifiers = languages.map { $0.minimalIdentifier }
            DispatchQueue.main.async {
                result(identifiers)
            }
        }
    }

    func handleTranslationAvailabilityAvailable(
        sourceIdentifier: String,
        targetIdentifier: String?,
        result: @escaping FlutterResult
    ) {
        Task {
            do {
                let sourceLanguage = try language(from: sourceIdentifier)
                let targetLanguage = try optionalLanguage(from: targetIdentifier)
                let availability = LanguageAvailability()
                let status = await availability.status(from: sourceLanguage, to: targetLanguage)
                let payload = translationAvailabilityPayload(
                    source: sourceLanguage,
                    target: targetLanguage,
                    status: status
                )
                DispatchQueue.main.async {
                    result(payload)
                }
            } catch {
                DispatchQueue.main.async {
                    result(self.makeFlutterError(from: error))
                }
            }
        }
    }

    func handlePrepareTranslationAvailable(
        sourceIdentifier: String,
        targetIdentifier: String?,
        result: @escaping FlutterResult
    ) {
        Task {
            do {
                let sourceLanguage = try language(from: sourceIdentifier)
                let targetLanguage = try optionalLanguage(from: targetIdentifier)
                let session = try TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
                try await session.prepareTranslation()
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(self.makeFlutterError(from: error))
                }
            }
        }
    }

    func language(from identifier: String) throws -> Locale.Language {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationError.unableToIdentifyLanguage
        }
        return Locale.Language(identifier: trimmed)
    }

    func optionalLanguage(from identifier: String?) throws -> Locale.Language? {
        guard let identifier else {
            return nil
        }
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return Locale.Language(identifier: trimmed)
    }

    func normalizedClientIdentifier(_ identifier: String?) -> String? {
        guard let identifier = identifier?.trimmingCharacters(in: .whitespacesAndNewlines), !identifier.isEmpty else {
            return nil
        }
        return identifier
    }

    func translationResponseDictionary(from response: TranslationSession.Response) -> [String: Any] {
        var payload: [String: Any] = [
            "sourceText": response.sourceText,
            "targetText": response.targetText
        ]

        payload["sourceLanguage"] = response.sourceLanguage.minimalIdentifier
        payload["targetLanguage"] = response.targetLanguage.minimalIdentifier
        if let client = response.clientIdentifier, !client.isEmpty {
            payload["clientIdentifier"] = client
        }

        return payload
    }

    func translationAvailabilityPayload(
        source: Locale.Language,
        target: Locale.Language?,
        status: LanguageAvailability.Status
    ) -> [String: Any] {
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
        var payload: [String: Any] = [
            "status": statusString,
            "isInstalled": isInstalled,
            "isSupported": isSupported,
            "sourceLanguage": source.minimalIdentifier
        ]

        if let targetIdentifier = target?.minimalIdentifier {
            payload["targetLanguage"] = targetIdentifier
        }

        return payload
    }
}

@available(iOS 26.0, *)
final class AppleIntelligenceStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: AppleIntelligenceFlutterPlugin?
    private var currentTask: Task<Void, Never>?
    private var currentSink: FlutterEventSink?

    init(plugin: AppleIntelligenceFlutterPlugin) {
        self.plugin = plugin
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if let runningTask = currentTask {
            runningTask.cancel()
            if let existingSink = currentSink {
                DispatchQueue.main.async {
                    existingSink(FlutterEndOfEventStream)
                }
            }
            currentTask = nil
            currentSink = nil
        }

        guard let params = arguments as? [String: Any], let prompt = params["prompt"] as? String else {
            return FlutterError(code: "invalid_arguments", message: "A non-empty 'prompt' string is required.", details: nil)
        }

        let context = params["context"] as? String
        let sessionId = params["sessionId"] as? String
        let optionsRaw = params["options"]
        let options: GenerationOptions?
        do {
            options = try parseGenerationOptions(from: optionsRaw)
        } catch let error as GenerationOptionsParsingError {
            return error.flutterError
        } catch {
            return plugin.makeFlutterError(from: error)
        }
        currentSink = events

        currentTask = Task { [weak self] in
            guard let self else { return }
            await self.stream(prompt: prompt, context: context, sessionId: sessionId, options: options, sink: events)
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        currentTask?.cancel()
        currentTask = nil
        currentSink = nil
        return nil
    }

    private func stream(prompt: String, context: String?, sessionId: String?, options: GenerationOptions?, sink: @escaping FlutterEventSink) async {
        guard let plugin else { return }

        let emit: (Any) -> Void = { value in
            DispatchQueue.main.async {
                sink(value)
            }
        }

        do {
            let manager = plugin.resolveSessionManager()
            let responseStream = try await manager.stream(prompt: prompt, context: context, sessionId: sessionId, options: options)

            var aggregatedText = ""
            var lastRaw: String?

            for try await snapshot in responseStream {
                try Task.checkCancellation()
                let raw = snapshot.rawContent.jsonString
                lastRaw = raw
                let extracted = Self.extractText(from: raw)

                var payload: [String: Any] = [
                    "done": false,
                    "raw": raw
                ]

                if let extracted, !extracted.isEmpty {
                    let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                    var delta: String?
                    if trimmed.hasPrefix(aggregatedText) {
                        delta = String(trimmed.dropFirst(aggregatedText.count))
                    } else if !trimmed.isEmpty {
                        delta = trimmed
                    }
                    aggregatedText = trimmed
                    if !trimmed.isEmpty {
                        payload["cumulativeText"] = trimmed
                    }
                    if let delta, !delta.isEmpty {
                        payload["deltaText"] = delta
                    }
                }

                emit(payload)
            }

            var completionPayload: [String: Any] = [
                "done": true
            ]
            if !aggregatedText.isEmpty {
                completionPayload["cumulativeText"] = aggregatedText
            }
            if let raw = lastRaw {
                completionPayload["raw"] = raw
            }

            emit(completionPayload)
            emit(FlutterEndOfEventStream)
        } catch is CancellationError {
            emit(FlutterEndOfEventStream)
        } catch {
            let flutterError = plugin.makeFlutterError(from: error)
            emit(flutterError)
            emit(FlutterEndOfEventStream)
        }

        currentTask = nil
        currentSink = nil
    }

    private static func extractText(from json: String) -> String? {
        guard !json.isEmpty else { return nil }

        // Handle plain JSON strings quickly.
        if json.first == "\"", json.last == "\"" {
            let unescaped = String(json.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\r")
                .replacingOccurrences(of: "\\t", with: "\t")
            return unescaped
        }

        guard let data = json.data(using: .utf8) else {
            return nil
        }

        // Attempt decoding as a bare string before falling back to JSON containers.
        if let directString = try? JSONDecoder().decode(String.self, from: data) {
            return directString
        }

        if let result = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]) {
            return flattenText(from: result)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private static func flattenText(from jsonObject: Any, depth: Int = 0) -> String? {
        switch jsonObject {
        case let string as String:
            return string
        case let array as [Any]:
            let joined = array.compactMap { flattenText(from: $0, depth: depth + 1) }.joined()
            return joined.isEmpty ? nil : joined
        case let dict as [String: Any]:
            var collected: [String] = []

            let prioritizedKeys = [
                "text",
                "string",
                "content",
                "value",
                "generatedText",
                "spokenText"
            ]

            for key in prioritizedKeys {
                if let value = dict[key] {
                    if let string = value as? String {
                        collected.append(string)
                    } else if let nested = flattenText(from: value, depth: depth + 1) {
                        collected.append(nested)
                    }
                }
            }

            let containerKeys = [
                "fragments",
                "choices",
                "content",
                "parts",
                "items",
                "children",
                "elements",
                "paragraphs"
            ]

            for key in containerKeys {
                if let value = dict[key] {
                    if let nested = flattenText(from: value, depth: depth + 1) {
                        collected.append(nested)
                    }
                }
            }

            if collected.isEmpty {
                for value in dict.values {
                    if let string = value as? String {
                        collected.append(string)
                    } else if let nested = flattenText(from: value, depth: depth + 1) {
                        collected.append(nested)
                    }
                }
            }

            let joined = collected.joined()
            return joined.isEmpty ? nil : joined
        default:
            return nil
        }
    }
}

final class UnsupportedStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        events(FlutterError(code: "unsupported_platform", message: "Apple Intelligence streaming requires iOS 26.0 or newer.", details: nil))
        events(FlutterEndOfEventStream)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        nil
    }
}
