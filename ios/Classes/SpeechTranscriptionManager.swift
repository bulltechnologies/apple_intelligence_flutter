import Foundation
#if canImport(Speech)
import Flutter
import Speech

@available(iOS 15.0, *)
struct SpeechTranscriptionResultPayload {
    let text: String
    let locale: String
    let segments: [[String: Any]]

    func asDictionary() -> [String: Any] {
        [
            "text": text,
            "locale": locale,
            "segments": segments
        ]
    }
}

@available(iOS 15.0, *)
enum SpeechTranscriptionError: Error {
    case authorizationDenied
    case recognizerUnavailable
    case fileNotFound
    case unknown
}

@available(iOS 15.0, *)
extension SpeechTranscriptionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Speech recognition authorization was denied."
        case .recognizerUnavailable:
            return "Speech recognizer is unavailable for the requested locale."
        case .fileNotFound:
            return "Audio file not found at the specified path."
        case .unknown:
            return "An unknown speech recognition error occurred."
        }
    }
}

@available(iOS 15.0, *)
final class SpeechTranscriptionManager {
    static let shared = SpeechTranscriptionManager()

    private init() {}

    func transcribeAudio(at url: URL, localeIdentifier: String?, requiresOnDevice: Bool?) async throws -> SpeechTranscriptionResultPayload {
        let status = await requestAuthorization()
        guard status == .authorized else {
            throw SpeechTranscriptionError.authorizationDenied
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SpeechTranscriptionError.fileNotFound
        }

        let recognizer = try makeRecognizer(localeIdentifier: localeIdentifier)
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if let requiresOnDevice {
            request.requiresOnDeviceRecognition = requiresOnDevice
        }

        return try await withCheckedThrowingContinuation { continuation in
            var hasCompleted = false

            _ = recognizer.recognitionTask(with: request) { result, error in
                if hasCompleted {
                    return
                }

                if let error {
                    hasCompleted = true
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else {
                    return
                }

                if result.isFinal {
                    hasCompleted = true

                    let transcription = result.bestTranscription
                    let segments = transcription.segments.map { segment -> [String: Any] in
                        [
                            "substring": segment.substring,
                            "timestamp": segment.timestamp,
                            "duration": segment.duration,
                            "confidence": segment.confidence
                        ]
                    }
                    let payload = SpeechTranscriptionResultPayload(
                        text: transcription.formattedString,
                        locale: recognizer.locale.identifier,
                        segments: segments
                    )
                    continuation.resume(returning: payload)
                }
            }
        }
    }

    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func makeRecognizer(localeIdentifier: String?) throws -> SFSpeechRecognizer {
        if let localeIdentifier,
           !localeIdentifier.isEmpty,
           let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) {
            return recognizer
        }

        if let recognizer = SFSpeechRecognizer() {
            return recognizer
        }

        throw SpeechTranscriptionError.recognizerUnavailable
    }
}

@available(iOS 15.0, *)
extension SpeechTranscriptionManager {
    static func handleTranscribeAudio(
        _ arguments: Any?,
        result: @escaping FlutterResult,
        errorMapper: @escaping (Error) -> FlutterError
    ) {
        guard let params = arguments as? [String: Any],
              let path = params["filePath"] as? String,
              !path.isEmpty else {
            result(FlutterError(code: "invalid_arguments", message: "A non-empty 'filePath' string is required.", details: nil))
            return
        }

        let locale = params["locale"] as? String
        let requiresOnDevice = params["requiresOnDeviceRecognition"] as? Bool
        let url = URL(fileURLWithPath: path)

        Task {
            do {
                let payload = try await SpeechTranscriptionManager.shared.transcribeAudio(
                    at: url,
                    localeIdentifier: locale,
                    requiresOnDevice: requiresOnDevice
                )
                DispatchQueue.main.async {
                    result(payload.asDictionary())
                }
            } catch {
                DispatchQueue.main.async {
                    result(errorMapper(error))
                }
            }
        }
    }
}
#endif
