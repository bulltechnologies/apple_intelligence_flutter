/// Base class for Apple Intelligence responses
abstract class AppleIntelligenceResponse {
  final bool success;
  final String? error;

  const AppleIntelligenceResponse({
    required this.success,
    this.error,
  });

  factory AppleIntelligenceResponse.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('Subclasses must implement fromJson');
  }
}

/// Response for text processing
class TextProcessingResponse extends AppleIntelligenceResponse {
  final String? processedText;
  final Map<String, dynamic>? metadata;

  const TextProcessingResponse({
    required super.success,
    super.error,
    this.processedText,
    this.metadata,
  });

  factory TextProcessingResponse.fromJson(Map<String, dynamic> json) {
    return TextProcessingResponse(
      success: json['success'] as bool,
      error: json['error'] as String?,
      processedText: json['processedText'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
