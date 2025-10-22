/// Base class for Apple Intelligence requests.
///
/// All request types extend this class and must implement [toJson] to serialize
/// their data for the platform channel.
abstract class AppleIntelligenceRequest {
  const AppleIntelligenceRequest();

  /// Converts this request to a JSON map for platform channel transmission.
  Map<String, dynamic> toJson();
}

/// Request for text processing operations using Apple Intelligence.
///
/// Contains the primary [text] to be processed and optional [context] to guide
/// the model's understanding and response generation.
class TextProcessingRequest extends AppleIntelligenceRequest {
  /// The primary text content to be processed by Apple Intelligence.
  final String text;

  /// Optional contextual information to guide the model's processing.
  final String? context;

  /// Creates a text processing request.
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
