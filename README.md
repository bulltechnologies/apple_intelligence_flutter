# Apple Intelligence Flutter

Flutter bindings for Apple’s on-device Foundation Models introduced with Apple Intelligence (iOS/iPadOS 26).

- 🚀 Send prompts to the system language model directly from Dart.
- 🌊 Stream partial responses as the model generates tokens.
- 🧠 Provide instructions/context to steer model behaviour, entirely offline.
- 🛡️ Robust availability checks and structured error reporting.
- 📱 Shipping example app and unit tests.

## Requirements

- Flutter 3.10 or newer.
- Xcode 16 beta (or newer) with the iOS 26 SDK.
- A device or simulator running iOS 26. Apple Intelligence must be enabled on device settings for real hardware.
- No additional authentication is required; the system model runs on-device.

## Installation

Add the package dependency:

```yaml
dependencies:
  apple_intelligence_flutter: ^0.1.0
```

Run `flutter pub get` to fetch the package.

## iOS setup

The Flutter plugin ships with an iOS-specific implementation. No extra CocoaPods are needed beyond the generated podspec, but ensure:

- Your app’s iOS deployment target is **26.0** or later (`ios/Runner.xcodeproj ▸ Build Settings ▸ iOS Deployment Target`).
- Apple Intelligence is enabled on the target device (Settings ▸ General ▸ Apple Intelligence).
- For simulators, boot an iOS 26 simulator image. Earlier versions won’t load the `FoundationModels` framework.

## Quick start

```dart
import 'package:apple_intelligence_flutter/apple_intelligence_flutter.dart';

final client = AppleIntelligenceClient.instance;

// 1. Configure Apple Intelligence with optional instructions.
final availability = await client.initialize(
  instructions: 'You are a concise, factual assistant.',
);

if (!availability.available) {
  debugPrint('Apple Intelligence unavailable: ${availability.reason}');
  return;
}

// 2a. Request a full response in a single await.
final response = await client.sendPrompt(
  prompt: 'Summarize the WWDC keynote in three bullet points.',
  context: 'Keep each bullet under 20 words.',
);
debugPrint(response.processedText);

// 2b. Or stream partial output as the model generates it.
await for (final chunk in client.streamPrompt(prompt: 'Draft a friendly reminder email.')) {
  if (chunk.delta != null) {
    debugPrint('Streaming update: ${chunk.delta}');
  } else if (chunk.cumulativeText != null) {
    debugPrint('Current text: ${chunk.cumulativeText}');
  }
}

// 3. Reuse the service façade when you prefer structured responses.
final service = TextProcessingService(client: client);
final serviceResponse = await service.processText(
  const TextProcessingRequest(text: 'List three creative uses for Markdown tables.'),
);

if (serviceResponse.success) {
  debugPrint(serviceResponse.processedText);
} else {
  debugPrint('Error: ${serviceResponse.error}');
}
```

## Prompting model

- **Instructions**: Call `initialize(instructions: ...)` once to describe the assistant’s behaviour. The same instruction set is reused for subsequent prompts.
- **Prompt**: Use `sendPrompt(prompt: ...)` with optional `context` to prepend structured guidance (e.g. UI state, safety rails).
- **Responses**: Successful calls return `TextProcessingResponse` with `processedText` and metadata containing the latest availability snapshot.
- **Streaming**: Use `AppleIntelligenceClient.streamPrompt` (or `TextProcessingService.streamText`) to receive `AppleIntelligenceStreamChunk` updates with cumulative and delta text. The last chunk is flagged with `isFinal` and includes the fully aggregated output.

## Availability and errors

`initialize` and `isAvailable` return `AppleIntelligenceAvailability`, which includes:

- `available` – `true` when `SystemLanguageModel` reports `.available`.
- `code` – machine readable status (`available`, `model_not_ready`, `device_not_eligible`, etc.).
- `reason` – short explanation suitable for user messaging.
- `sessionReady` – `true` when an underlying `LanguageModelSession` is already created.

All failures throw `AppleIntelligenceException`, exposing `code`, `message`, and optional native `details`. Generation errors bubble up messages from `FoundationModels` (for example, context window exceeded or guardrail violations).

## Example app

The [`example`](example/) project demonstrates:

- Reactive availability UI.
- Contextual prompting from text fields.
- Displaying metadata/error details returned by the plugin.

Run it on an iOS 26 simulator or device:

```bash
cd example
flutter run
```

## Testing & linting

The package includes widget-test-style unit coverage of the method channel. Run

```bash
flutter test
```

to execute them. The codebase uses `flutter format` and `flutter_lints` defaults.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `unsupported_platform` errors | Ensure you deploy to iOS 26 or newer. macOS/Android/web builds short-circuit with this code by design. |
| `model_not_ready` | The system model is still downloading. Wait for the device to finish preparing Apple Intelligence resources. |
| `apple_intelligence_not_enabled` | Enable Apple Intelligence under **Settings ▸ General ▸ Apple Intelligence** on the device. |
| Build fails with `FoundationModels` not found | Confirm Xcode is pointing to the iOS 26 SDK and that you opened the workspace generated by Flutter (`Runner.xcworkspace`). |

## License

MIT License – see [LICENSE](LICENSE).
