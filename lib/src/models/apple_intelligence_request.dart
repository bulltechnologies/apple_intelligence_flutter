/// Base class for Apple Intelligence requests
abstract class AppleIntelligenceRequest {
  const AppleIntelligenceRequest();

  Map<String, dynamic> toJson();
}

/// Request for text processing
class TextProcessingRequest extends AppleIntelligenceRequest {
  final String text;
  final String? context;

  const TextProcessingRequest({
    required this.text,
    this.context,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (context != null) 'context': context,
    };
  }
}
