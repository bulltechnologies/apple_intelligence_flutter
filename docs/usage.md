# Usage Guide

This document walks through integrating the `apple_intelligence_flutter` package into a Flutter application, configuring Apple Intelligence, and handling common runtime scenarios.

## 1. Prerequisites

- Flutter 3.10+ installed (`flutter --version`).
- Xcode 16 beta (or newer) with the iOS 26 SDK.
- A device or simulator running iOS 26. Apple Intelligence must be enabled on hardware devices under **Settings ▸ General ▸ Apple Intelligence**.
- An Apple Developer account capable of running iOS betas.

## 2. Add the dependency

Update your app’s `pubspec.yaml`:

```yaml
dependencies:
  apple_intelligence_flutter: ^0.1.0
```

Fetch packages:

```bash
flutter pub get
```

## 3. Configure the iOS target

The plugin only ships an iOS implementation. Ensure the Runner target is set to the correct deployment target and that you open the generated workspace:

1. Update `ios/Podfile` if necessary:
   ```ruby
   platform :ios, '16.0'
   ```
   Flutter will set the minimum to 16 by default; the plugin enforces iOS 26 at build/runtime.
2. Open `ios/Runner.xcworkspace` in Xcode.
3. In **Build Settings**, set **iOS Deployment Target** to **26.0**.
4. Build once from Xcode or run `flutter run` on an iOS 26 simulator/device.

No entitlements or server-side authentication are required. The `FoundationModels` framework executes on-device.

## 4. Initialize Apple Intelligence

Create a shared instance early in your app lifecycle (e.g. in a provider, bloc, or top-level service):

```dart
final client = AppleIntelligenceClient.instance;

Future<AppleIntelligenceAvailability> warmUpAppleIntelligence() async {
  final availability = await client.initialize(
    instructions: '''
      You are a product assistant. Respond in short, factual sentences.
      Never invent personal data.
    ''',
  );

  if (!availability.available) {
    debugPrint('Apple Intelligence unavailable: ${availability.reason}');
  }

  return availability;
}
```

The returned `AppleIntelligenceAvailability` can be cached to drive UI state (e.g. showing a banner when the model isn’t ready).

## 5. Send prompts

Two approaches are supported:

### Direct client

```dart
final response = await client.sendPrompt(
  prompt: 'Draft a polite follow-up email about a missed meeting.',
  context: 'Keep it under 120 words and mention tomorrow afternoon as a new option.',
);

if (response.success) {
  debugPrint(response.processedText);
}
```

### Service façade

The `TextProcessingService` retains compatibility with the initial library design and returns `TextProcessingResponse` objects:

```dart
final service = TextProcessingService(client: client);
final result = await service.processText(
  const TextProcessingRequest(
    text: 'Summarize the patch notes in three bullet points.',
  ),
);

if (!result.success) {
  debugPrint('Failure: ${result.error}');
}
```

## 6. Handle errors

All failures throw `AppleIntelligenceException` with:

- `code` – short identifier (`unsupported_platform`, `empty_prompt`, `generation_error`, etc.).
- `message` – localized description.
- `details` – platform-provided metadata (availability info, failure reasons, recovery suggestions).

Example handling:

```dart
try {
  final response = await client.sendPrompt(prompt: userInput);
  // Use response.processedText.
} on AppleIntelligenceException catch (error) {
  switch (error.code) {
    case 'unsupported_platform':
      // Show a message or disable the feature on non-iOS builds.
      break;
    case 'unavailable':
      final info = error.details as Map<String, dynamic>?;
      debugPrint('Model unavailable: ${info?['reason']}');
      break;
    default:
      debugPrint('Apple Intelligence error: ${error.message}');
  }
}
```

## 7. Availability cheatsheet

| Code | Meaning | Typical Resolution |
| --- | --- | --- |
| `available` | Ready to accept prompts. | None. |
| `model_not_ready` | Model is still downloading or preparing. | Wait and retry later. |
| `apple_intelligence_not_enabled` | Apple Intelligence disabled in settings. | Instruct the user to enable it. |
| `device_not_eligible` | Hardware does not support Apple Intelligence. | Provide fallback behaviour. |
| `unsupported_platform` | Non-iOS build or iOS <26. | Restrict feature to supported platforms. |

## 8. Stream responses

When you prefer partial updates, call `AppleIntelligenceClient.streamPrompt` (or `TextProcessingService.streamText`).

```dart
final chunks = client.streamPrompt(
  prompt: 'Create a friendly reminder email for tomorrow\'s meeting.',
);

await for (final chunk in chunks) {
  if (chunk.cumulativeText != null) {
    debugPrint('[stream] ${chunk.delta ?? chunk.cumulativeText}');
  }

  if (chunk.isFinal) {
    debugPrint('Final text: ${chunk.cumulativeText}');
  }
}
```

Each chunk includes:

- `cumulativeText`: Full text generated so far.
- `delta`: Convenience helper representing just the new portion since the previous chunk (when available).
- `rawJson`: Raw `GeneratedContent` JSON for advanced parsing.
- `isFinal`: Marks the final event in the stream.

If the stream reports a `FlutterError` from native code, it is mapped to `AppleIntelligenceException` so existing error handling applies.

Cancel the subscription to abort generation:

```dart
final subscription = chunks.listen(...);
// Later
await subscription.cancel();
```

## 9. Testing strategy

The package uses Flutter test bindings to mock the method channel. When writing your own tests:

```dart
setUp(() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    // Return canned responses for initialize/sendPrompt.
  });
});
```

Remember to clear handlers in `tearDown()` to avoid leakage between tests.

## 10. Troubleshooting checklist

- **Build fails with `FoundationModels` not found**: reopen the generated `.xcworkspace` and ensure Xcode uses an iOS 26 SDK.
- **`generation_error`**: inspect `error.details` for `failureReason`. Often caused by exceeding context length or an unsupported locale.
- **Nothing happens on prompt**: check `_availability.sessionReady`; if `false`, call `initialize` before sending prompts to warm up the session.

## 11. Example app walkthrough

The sample in `example/lib/main.dart` demonstrates:

1. Performing initialization inside `initState()`.
2. Displaying availability status with descriptive icons.
3. Submitting prompt/context pairs from two text fields.
4. Rendering the returned metadata to help debug device state.

Use it as a reference when integrating the plugin into your production app.
