import Flutter
import Foundation
import FoundationModels

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
            handleIsAvailable(result: result)
        case "sendPrompt":
            handleSendPrompt(call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Handles initialization and instructions configuration.
    private func handleInitialize(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedPlatformPayload())
            return
        }

        let instructions = (arguments as? [String: Any])?["instructions"] as? String

        Task {
            do {
                let manager = resolveSessionManager()
                let initResult = try await manager.configure(with: instructions)
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
    private func handleIsAvailable(result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedPlatformPayload())
            return
        }

        Task {
            let manager = resolveSessionManager()
            let snapshot = await manager.availabilitySnapshot()
            DispatchQueue.main.async {
                result(snapshot.asDictionary())
            }
        }
    }

    /// Performs generation using the managed `LanguageModelSession`.
    private func handleSendPrompt(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(unsupportedPlatformError())
            return
        }

        guard let params = arguments as? [String: Any], let prompt = params["prompt"] as? String else {
            result(FlutterError(code: "invalid_arguments", message: "A non-empty 'prompt' string is required.", details: nil))
            return
        }

        let context = params["context"] as? String

        Task {
            do {
                let manager = resolveSessionManager()
                let response = try await manager.generate(prompt: prompt, context: context)
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
    private func unsupportedPlatformPayload() -> [String: Any] {
        [
            "available": false,
            "code": "unsupported_platform",
            "reason": "Apple Intelligence requires iOS 26.0 or newer."
        ]
    }

    /// Convenience error returned to Flutter when the platform is unsupported.
    private func unsupportedPlatformError() -> FlutterError {
        FlutterError(code: "unsupported_platform", message: "Apple Intelligence requires iOS 26.0 or newer.", details: nil)
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

    /// Removes nil values from an error-details dictionary.
    private func sanitizedDetails(_ dictionary: [String: Any?]) -> [String: Any]? {
        let filtered = dictionary.compactMapValues { $0 }
        return filtered.isEmpty ? nil : filtered
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
        currentSink = events

        currentTask = Task { [weak self] in
            guard let self else { return }
            await self.stream(prompt: prompt, context: context, sink: events)
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        currentTask?.cancel()
        currentTask = nil
        currentSink = nil
        return nil
    }

    private func stream(prompt: String, context: String?, sink: @escaping FlutterEventSink) async {
        guard let plugin else { return }

        let emit: (Any) -> Void = { value in
            DispatchQueue.main.async {
                sink(value)
            }
        }

        do {
            let manager = plugin.resolveSessionManager()
            let responseStream = try await manager.stream(prompt: prompt, context: context)

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
