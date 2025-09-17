/// Flutter bindings for Apple Intelligence on-device Foundation Models.
///
/// This library exposes a Dart-friendly API that bridges to Apple's
/// `FoundationModels` framework through a platform plugin. Use
/// [AppleIntelligenceClient] to manage availability, initialize sessions
/// with custom instructions, and send prompts that run entirely on-device.
library apple_intelligence_flutter;

export 'src/apple_intelligence_client.dart';
export 'src/models/models.dart';
export 'src/services/services.dart';
