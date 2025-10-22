/// Generation settings that control how Apple Intelligence produces text.
///
/// These options allow fine-tuning of the model's behavior including creativity
/// level, response length, and sampling strategy.
class AppleIntelligenceGenerationOptions {
  /// Creates generation options with optional parameters.
  const AppleIntelligenceGenerationOptions({
    this.temperature,
    this.maximumResponseTokens,
    this.samplingMode,
  });

  /// Controls randomness in generation (0.0 = deterministic, 1.0 = very creative).
  final double? temperature;

  /// Maximum number of tokens to generate in the response.
  final int? maximumResponseTokens;

  /// The sampling strategy to use during text generation.
  final AppleIntelligenceSamplingMode? samplingMode;

  /// Converts these options to a JSON map for platform channel transmission.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (temperature != null) 'temperature': temperature,
      if (maximumResponseTokens != null) 'maximumResponseTokens': maximumResponseTokens,
      if (samplingMode != null) 'samplingMode': samplingMode!.toJson(),
    };
  }
}

/// Base class for generation sampling strategies.
///
/// Sampling modes control how the model selects tokens during text generation.
/// Different strategies offer trade-offs between consistency and creativity.
abstract class AppleIntelligenceSamplingMode {
  const AppleIntelligenceSamplingMode();

  /// Converts this sampling mode to a JSON map for platform channel transmission.
  Map<String, dynamic> toJson();
}

/// Always selects the most likely token at each generation step.
///
/// This sampling mode produces deterministic, consistent outputs but may be
/// less creative than probabilistic sampling strategies.
class AppleIntelligenceGreedySamplingMode extends AppleIntelligenceSamplingMode {
  /// Creates a greedy sampling mode instance.
  const AppleIntelligenceGreedySamplingMode();

  @override
  Map<String, dynamic> toJson() => const <String, dynamic>{
        'type': 'greedy',
      };
}

/// Randomly samples from the top-K most likely tokens.
///
/// This sampling mode provides a balance between consistency and creativity by
/// limiting the selection to the most probable tokens while still allowing
/// for randomness within that subset.
class AppleIntelligenceRandomTopSamplingMode extends AppleIntelligenceSamplingMode {
  /// Creates a top-K sampling mode.
  const AppleIntelligenceRandomTopSamplingMode({
    required this.topK,
    this.seed,
  }) : assert(topK > 0, 'topK must be greater than 0');

  /// The number of top tokens to consider for sampling (must be > 0).
  final int topK;

  /// Optional random seed for reproducible sampling.
  final int? seed;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'randomTop',
        'top': topK,
        if (seed != null) 'seed': seed,
      };
}

/// Randomly samples from tokens that accumulate to a probability threshold.
///
/// This sampling mode (also known as nucleus sampling or top-p sampling)
/// dynamically adjusts the candidate set based on cumulative probability,
/// providing adaptive creativity control.
class AppleIntelligenceRandomProbabilitySamplingMode extends AppleIntelligenceSamplingMode {
  /// Creates a probability-based sampling mode.
  const AppleIntelligenceRandomProbabilitySamplingMode({
    required this.probabilityThreshold,
    this.seed,
  }) : assert(
          probabilityThreshold >= 0 && probabilityThreshold <= 1,
          'probabilityThreshold must be between 0 and 1',
        );

  /// The cumulative probability threshold for token selection (0.0 to 1.0).
  final double probabilityThreshold;

  /// Optional random seed for reproducible sampling.
  final int? seed;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'randomProbability',
        'probabilityThreshold': probabilityThreshold,
        if (seed != null) 'seed': seed,
      };
}
