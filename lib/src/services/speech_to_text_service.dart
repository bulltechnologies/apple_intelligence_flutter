import 'package:flutter/services.dart';

import '../models/models.dart';
import '../apple_intelligence_client.dart' show AppleIntelligenceException;

/// Service that exposes iOS speech recognition via the platform channel.
///
/// This service provides access to iOS Speech framework capabilities for
/// transcribing audio files into text with optional timing information.
class SpeechToTextService {
  /// Creates a speech-to-text service with an optional method channel.
  SpeechToTextService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('apple_intelligence_flutter');

  final MethodChannel _channel;

  /// Transcribe an audio file on disk (for example an MP3 recording) into text.
  ///
  /// The file path must point to a location readable by the host platform
  /// (typically obtained from `path_provider`). Optional [locale] controls the
  /// recognizer language (defaults to the system locale). Set
  /// [requiresOnDeviceRecognition] to `true` to force on-device recognition
  /// when supported.
  Future<SpeechTranscriptionResult> transcribeAudioFile({
    required String filePath,
    String? locale,
    bool? requiresOnDeviceRecognition,
  }) async {
    if (filePath.trim().isEmpty) {
      throw const AppleIntelligenceException(
        code: 'invalid_arguments',
        message: 'filePath must not be empty.',
      );
    }

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'transcribeAudio',
        <String, dynamic>{
          'filePath': filePath,
          if (locale != null) 'locale': locale,
          if (requiresOnDeviceRecognition != null) 'requiresOnDeviceRecognition': requiresOnDeviceRecognition,
        },
      );

      if (response == null) {
        throw const AppleIntelligenceException(
          code: 'speech_transcription_failed',
          message: 'No response from speech recognizer.',
        );
      }

      return SpeechTranscriptionResult.fromJson(response);
    } on PlatformException catch (error) {
      throw AppleIntelligenceException.fromPlatformException(error);
    }
  }
}
