/// Generation settings that control how Apple Intelligence produces text.
class AppleIntelligenceGenerationOptions {
  const AppleIntelligenceGenerationOptions({
    this.temperature,
    this.maximumResponseTokens,
    this.samplingMode,
  });

  final double? temperature;
  final int? maximumResponseTokens;
  final AppleIntelligenceSamplingMode? samplingMode;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (temperature != null) 'temperature': temperature,
      if (maximumResponseTokens != null) 'maximumResponseTokens': maximumResponseTokens,
      if (samplingMode != null) 'samplingMode': samplingMode!.toJson(),
    };
  }
}

/// Base class for generation sampling strategies.
abstract class AppleIntelligenceSamplingMode {
  const AppleIntelligenceSamplingMode();

  Map<String, dynamic> toJson();
}

/// Always selects the most likely token at each generation step.
class AppleIntelligenceGreedySamplingMode extends AppleIntelligenceSamplingMode {
  const AppleIntelligenceGreedySamplingMode();

  @override
  Map<String, dynamic> toJson() => const <String, dynamic>{
        'type': 'greedy',
      };
}

/// Randomly samples from the top-K most likely tokens.
class AppleIntelligenceRandomTopSamplingMode extends AppleIntelligenceSamplingMode {
  const AppleIntelligenceRandomTopSamplingMode({
    required this.topK,
    this.seed,
  }) : assert(topK > 0, 'topK must be greater than 0');

  final int topK;
  final int? seed;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'randomTop',
        'top': topK,
        if (seed != null) 'seed': seed,
      };
}

/// Randomly samples from tokens that accumulate to a probability threshold.
class AppleIntelligenceRandomProbabilitySamplingMode extends AppleIntelligenceSamplingMode {
  const AppleIntelligenceRandomProbabilitySamplingMode({
    required this.probabilityThreshold,
    this.seed,
  }) : assert(
          probabilityThreshold >= 0 && probabilityThreshold <= 1,
          'probabilityThreshold must be between 0 and 1',
        );

  final double probabilityThreshold;
  final int? seed;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'randomProbability',
        'probabilityThreshold': probabilityThreshold,
        if (seed != null) 'seed': seed,
      };
}
