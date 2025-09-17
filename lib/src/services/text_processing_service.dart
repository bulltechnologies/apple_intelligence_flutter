import '../apple_intelligence_client.dart';
import '../models/models.dart';

/// Convenience service that wraps [AppleIntelligenceClient] for text prompts.
///
/// The service aligns with the initial package scaffold and provides a
/// reusable abstraction should additional request/response types be added in
/// the future.
class TextProcessingService {
  TextProcessingService({AppleIntelligenceClient? client})
      : _client = client ?? AppleIntelligenceClient.instance;

  final AppleIntelligenceClient _client;

  /// Process text using Apple Intelligence.
  ///
  /// The same validation and error semantics as
  /// [AppleIntelligenceClient.sendPrompt] apply, but results are returned as a
  /// [TextProcessingResponse] for compatibility with the original API design.
  Future<TextProcessingResponse> processText(
      TextProcessingRequest request) async {
    try {
      return await _client.sendPrompt(
        prompt: request.text,
        context: request.context,
      );
    } on AppleIntelligenceException catch (error) {
      return TextProcessingResponse(
        success: false,
        error: error.message,
        metadata: {
          'code': error.code,
          if (error.details != null) 'details': error.details,
        },
      );
    } catch (error) {
      return TextProcessingResponse(
        success: false,
        error: 'Failed to process text: $error',
      );
    }
  }

  /// Stream incremental updates as Apple Intelligence generates the response.
  Stream<AppleIntelligenceStreamChunk> streamText(
      TextProcessingRequest request) {
    return _client.streamPrompt(
      prompt: request.text,
      context: request.context,
    );
  }
}
