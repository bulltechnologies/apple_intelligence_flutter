/// A segment of transcribed speech with timing information.
class SpeechTranscriptionSegment {
  /// Creates a speech transcription segment.
  const SpeechTranscriptionSegment({
    required this.substring,
    required this.timestamp,
    required this.duration,
    this.confidence,
  });

  /// Creates a segment from JSON data.
  factory SpeechTranscriptionSegment.fromJson(Map<String, dynamic> json) {
    return SpeechTranscriptionSegment(
      substring: json['substring'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  /// The transcribed text for this segment.
  final String substring;

  /// The start time of this segment in seconds.
  final double timestamp;

  /// The duration of this segment in seconds.
  final double duration;

  /// The confidence score for this segment (0.0 to 1.0), if available.
  final double? confidence;

  /// Converts this segment to JSON.
  Map<String, dynamic> toJson() => {
        'substring': substring,
        'timestamp': timestamp,
        'duration': duration,
        if (confidence != null) 'confidence': confidence,
      };
}

/// The result of speech transcription containing the full text and timing segments.
class SpeechTranscriptionResult {
  /// Creates a speech transcription result.
  const SpeechTranscriptionResult({
    required this.text,
    required this.locale,
    required this.segments,
  });

  /// Creates a result from JSON data.
  factory SpeechTranscriptionResult.fromJson(Map<String, dynamic> json) {
    final segments = (json['segments'] as List?)
            ?.cast<Map<dynamic, dynamic>>()
            .map((segment) => SpeechTranscriptionSegment.fromJson(
                  segment.map((key, value) => MapEntry(key as String, value)),
                ))
            .toList() ??
        const <SpeechTranscriptionSegment>[];

    return SpeechTranscriptionResult(
      text: json['text'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      segments: segments,
    );
  }

  /// The complete transcribed text.
  final String text;

  /// The locale used for transcription.
  final String locale;

  /// Individual segments with timing information.
  final List<SpeechTranscriptionSegment> segments;

  /// Converts this result to JSON.
  Map<String, dynamic> toJson() => {
        'text': text,
        'locale': locale,
        'segments': segments.map((segment) => segment.toJson()).toList(),
      };
}
