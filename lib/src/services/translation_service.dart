import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../apple_intelligence_client.dart' show AppleIntelligenceException;
import '../models/translation_availability_status.dart';
import '../models/translation_result.dart';

/// Service wrapper around Apple's Translation framework.
///
/// This service provides access to iOS Translation framework capabilities for
/// translating text between supported languages with on-device processing.
class TranslationService {
  /// Creates a translation service wired to the plugin method channel.
  TranslationService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('apple_intelligence_flutter');

  final MethodChannel _channel;

  bool get _isSupportedPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Translates [text] from [sourceLanguage] to [targetLanguage].
  ///
  /// Both language parameters should be BCP 47 identifiers (e.g., 'en', 'es-MX').
  /// The optional [clientIdentifier] can be used to correlate requests when
  /// batching multiple translations.
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? clientIdentifier,
  }) async {
    if (!_isSupportedPlatform) {
      throw const AppleIntelligenceException(
        code: 'unsupported_platform',
        message: 'Translation requires iOS 26.0 or newer.',
      );
    }

    final sanitizedText = text.trim();
    if (sanitizedText.isEmpty) {
      throw const AppleIntelligenceException(
        code: 'translation_empty_text',
        message: 'Text to translate must not be empty.',
      );
    }

    final sanitizedSource = sourceLanguage.trim();
    final sanitizedTarget = targetLanguage.trim();
    if (sanitizedSource.isEmpty || sanitizedTarget.isEmpty) {
      throw const AppleIntelligenceException(
        code: 'translation_invalid_language',
        message: 'Both sourceLanguage and targetLanguage must be non-empty BCP 47 identifiers.',
      );
    }

    final sanitizedClientId = clientIdentifier?.trim();

    final args = <String, dynamic>{
      'text': sanitizedText,
      'sourceLanguage': sanitizedSource,
      'targetLanguage': sanitizedTarget,
      if (sanitizedClientId != null && sanitizedClientId.isNotEmpty) 'clientIdentifier': sanitizedClientId,
    };

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'translateText',
        args,
      );

      if (response == null) {
        throw const AppleIntelligenceException(
          code: 'translation_no_response',
          message: 'Platform translation returned no response.',
        );
      }

      return TranslationResult.fromJson(response);
    } on PlatformException catch (error) {
      throw AppleIntelligenceException.fromPlatformException(error);
    }
  }

  /// Returns availability information for a language pairing.
  ///
  /// Checks whether translation between [sourceLanguage] and optional
  /// [targetLanguage] is supported and whether language models are installed.
  Future<TranslationAvailabilityStatus> availability({
    required String sourceLanguage,
    String? targetLanguage,
  }) async {
    if (!_isSupportedPlatform) {
      throw const AppleIntelligenceException(
        code: 'unsupported_platform',
        message: 'Translation requires iOS 26.0 or newer.',
      );
    }

    final sanitizedSource = sourceLanguage.trim();
    if (sanitizedSource.isEmpty) {
      throw const AppleIntelligenceException(
        code: 'translation_invalid_language',
        message: 'sourceLanguage must be a non-empty BCP 47 identifier.',
      );
    }

    final sanitizedTarget = targetLanguage?.trim();

    final args = <String, dynamic>{
      'sourceLanguage': sanitizedSource,
      if (sanitizedTarget != null && sanitizedTarget.isNotEmpty) 'targetLanguage': sanitizedTarget,
    };

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'translationAvailability',
        args,
      );

      if (response == null) {
        throw const AppleIntelligenceException(
          code: 'translation_availability_failed',
          message: 'Translation availability returned no response.',
        );
      }

      return TranslationAvailabilityStatus.fromJson(response);
    } on PlatformException catch (error) {
      throw AppleIntelligenceException.fromPlatformException(error);
    }
  }

  /// Lists system supported translation language identifiers.
  ///
  /// Returns a list of BCP 47 language identifiers that are supported by the
  /// iOS Translation framework on this device.
  Future<List<String>> supportedLanguages() async {
    if (!_isSupportedPlatform) {
      throw const AppleIntelligenceException(
        code: 'unsupported_platform',
        message: 'Translation requires iOS 26.0 or newer.',
      );
    }

    try {
      final response = await _channel.invokeMethod<List<dynamic>>(
        'translationSupportedLanguages',
      );

      final languages = (response ?? const <dynamic>[])
          .map((value) => (value as String?)?.trim() ?? '')
          .where((language) => language.isNotEmpty)
          .toList(growable: false);

      return languages;
    } on PlatformException catch (error) {
      throw AppleIntelligenceException.fromPlatformException(error);
    }
  }

  /// Prompts iOS to download required translation assets ahead of time.
  ///
  /// Pre-downloads language models for [sourceLanguage] and optional
  /// [targetLanguage] to ensure faster translation when needed.
  Future<void> prepareTranslation({
    required String sourceLanguage,
    String? targetLanguage,
  }) async {
    if (!_isSupportedPlatform) {
      throw const AppleIntelligenceException(
        code: 'unsupported_platform',
        message: 'Translation requires iOS 26.0 or newer.',
      );
    }

    final sanitizedSource = sourceLanguage.trim();
    if (sanitizedSource.isEmpty) {
      throw const AppleIntelligenceException(
        code: 'translation_invalid_language',
        message: 'sourceLanguage must be a non-empty BCP 47 identifier.',
      );
    }

    final sanitizedTarget = targetLanguage?.trim();

    final args = <String, dynamic>{
      'sourceLanguage': sanitizedSource,
      if (sanitizedTarget != null && sanitizedTarget.isNotEmpty) 'targetLanguage': sanitizedTarget,
    };

    try {
      await _channel.invokeMethod('prepareTranslation', args);
    } on PlatformException catch (error) {
      throw AppleIntelligenceException.fromPlatformException(error);
    }
  }
}
