/// Available use cases supported by `SystemLanguageModel`.
///
/// The identifiers map directly to the native `SystemLanguageModel.UseCase`
/// type so that values can pass through the platform channel without any
/// additional translation.
enum AppleIntelligenceUseCase {
  general('general', aliases: ['default']),
  contentTagging('contentTagging', aliases: ['content_tagging', 'content-tagging']);

  const AppleIntelligenceUseCase(this.identifier, {this.aliases = const []});

  /// Identifier understood by the native plugin.
  final String identifier;

  /// Alternative names accepted during parsing.
  final List<String> aliases;

  /// Serializes the use case for the platform channel payload.
  String toJson() => identifier;

  /// Attempts to parse an identifier into a supported use case.
  static AppleIntelligenceUseCase? maybeFrom(String? raw) {
    if (raw == null) {
      return null;
    }

    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lowered = normalized.toLowerCase();
    for (final useCase in AppleIntelligenceUseCase.values) {
      if (lowered == useCase.identifier.toLowerCase()) {
        return useCase;
      }
      if (useCase.aliases.any((alias) => lowered == alias.toLowerCase())) {
        return useCase;
      }
    }
    return null;
  }

  /// Resolves an identifier into a use case, defaulting to [general] when
  /// parsing fails.
  static AppleIntelligenceUseCase resolve(String? raw) {
    return maybeFrom(raw) ?? AppleIntelligenceUseCase.general;
  }

  /// Returns a list of all supported identifiers.
  static List<String> get supportedIdentifiers =>
      AppleIntelligenceUseCase.values.map((value) => value.identifier).toList(growable: false);
}
