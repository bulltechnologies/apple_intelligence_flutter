import 'package:apple_intelligence_flutter/apple_intelligence_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('apple_intelligence_flutter');
  final service = SpeechToTextService(channel: channel);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('transcribeAudioFile returns transcription result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'transcribeAudio');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['filePath'], '/tmp/audio.mp3');
      return {
        'text': 'hello world',
        'locale': 'en-US',
        'segments': [
          {
            'substring': 'hello',
            'timestamp': 0.0,
            'duration': 0.5,
            'confidence': 0.9,
          },
          {
            'substring': 'world',
            'timestamp': 0.6,
            'duration': 0.5,
            'confidence': 0.8,
          }
        ],
      };
    });

    final result =
        await service.transcribeAudioFile(filePath: '/tmp/audio.mp3');
    expect(result.text, 'hello world');
    expect(result.locale, 'en-US');
    expect(result.segments, hasLength(2));
    expect(result.segments.first.substring, 'hello');
  });

  test('transcribeAudioFile throws when filePath empty', () async {
    expect(
      () => service.transcribeAudioFile(filePath: ''),
      throwsA(isA<AppleIntelligenceException>()),
    );
  });
}
