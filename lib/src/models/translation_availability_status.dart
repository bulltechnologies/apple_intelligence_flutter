/// Describes translation language availability information reported by iOS.
class TranslationAvailabilityStatus {
  /// Creates a status snapshot.
  const TranslationAvailabilityStatus({
    required this.status,
    required this.isInstalled,
    required this.isSupported,
    required this.sourceLanguage,
    this.targetLanguage,
  });

  /// Builds a status object from JSON returned by the platform.
  factory TranslationAvailabilityStatus.fromJson(Map<String, dynamic> json) {
    return TranslationAvailabilityStatus(
      status: json['status'] as String? ?? 'unknown',
      isInstalled: json['isInstalled'] as bool? ?? false,
      isSupported: json['isSupported'] as bool? ?? false,
      sourceLanguage: json['sourceLanguage'] as String? ?? '',
      targetLanguage: json['targetLanguage'] as String?,
    );
  }

  /// Status identifier, e.g. `installed`, `supported`, or `unsupported`.
  final String status;

  /// True when both languages are already installed on device.
  final bool isInstalled;

  /// True when the translation pairing is supported (installed or downloadable).
  final bool isSupported;

  /// Source language BCP 47 identifier.
  final String sourceLanguage;

  /// Target language BCP 47 identifier, when provided.
  final String? targetLanguage;

  /// Convenience getter for translation readiness.
  bool get canTranslate => isInstalled;

  /// Indicates whether the pairing can be downloaded for on-device use.
  bool get canDownload => isSupported && !isInstalled;

  /// Converts status to JSON.
  Map<String, dynamic> toJson() => {
        'status': status,
        'isInstalled': isInstalled,
        'isSupported': isSupported,
        'sourceLanguage': sourceLanguage,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      };
}
