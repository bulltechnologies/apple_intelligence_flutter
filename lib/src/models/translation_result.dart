/// Represents the outcome of a translation request.
class TranslationResult {
  /// Creates a translation result instance.
  const TranslationResult({
    required this.sourceText,
    required this.targetText,
    this.sourceLanguage,
    this.targetLanguage,
    this.clientIdentifier,
  });

  /// Creates a result object from JSON returned by the platform channel.
  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      sourceText: json['sourceText'] as String? ?? '',
      targetText: json['targetText'] as String? ?? '',
      sourceLanguage: json['sourceLanguage'] as String?,
      targetLanguage: json['targetLanguage'] as String?,
      clientIdentifier: json['clientIdentifier'] as String?,
    );
  }

  /// The original text that was translated.
  final String sourceText;

  /// The translated output text.
  final String targetText;

  /// BCP 47 identifier of the detected or supplied source language.
  final String? sourceLanguage;

  /// BCP 47 identifier of the target language.
  final String? targetLanguage;

  /// Optional identifier used to correlate responses when batching requests.
  final String? clientIdentifier;

  /// Converts the result into a JSON map.
  Map<String, dynamic> toJson() => {
        'sourceText': sourceText,
        'targetText': targetText,
        if (sourceLanguage != null) 'sourceLanguage': sourceLanguage,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
        if (clientIdentifier != null) 'clientIdentifier': clientIdentifier,
      };
}
