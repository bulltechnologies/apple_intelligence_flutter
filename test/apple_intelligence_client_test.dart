import 'package:apple_intelligence_flutter/apple_intelligence_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('apple_intelligence_flutter');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('apple_intelligence_flutter/stream', null);
  });

  test('initialize returns availability from platform', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'initialize');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args, isEmpty);
      return {
        'available': true,
        'code': 'available',
        'sessionReady': true,
      };
    });

    final availability = await AppleIntelligenceClient.instance.initialize();

    expect(availability.available, isTrue);
    expect(availability.code, 'available');
    expect(availability.sessionReady, isTrue);
  });

  test('sendPrompt returns a successful response', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'initialize':
          return {
            'available': true,
            'code': 'available',
            'sessionReady': true,
          };
        case 'sendPrompt':
          final args = call.arguments as Map<dynamic, dynamic>;
          expect(args['prompt'], 'Tell me a story');
          expect(args['context'], 'Be concise');
          return 'Once upon a time';
        default:
          fail('Unexpected method: ${call.method}');
      }
    });

    final client = AppleIntelligenceClient.instance;
    await client.initialize(instructions: 'You are a helpful assistant.');

    final response = await client.sendPrompt(
      prompt: '  Tell me a story  ',
      context: '  Be concise  ',
    );

    expect(response.success, isTrue);
    expect(response.processedText, 'Once upon a time');
    expect(response.metadata?['code'], 'available');
  });

  test('sendPrompt throws on empty prompt without hitting platform channel',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var invoked = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      invoked = true;
      return null;
    });

    expect(
      () => AppleIntelligenceClient.instance.sendPrompt(prompt: '   '),
      throwsA(
        isA<AppleIntelligenceException>().having(
          (error) => error.code,
          'code',
          'empty_prompt',
        ),
      ),
    );

    expect(invoked, isFalse);
  });

  test('streamPrompt emits chunks and closes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    const MethodCodec codec = StandardMethodCodec();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'apple_intelligence_flutter/stream',
      (ByteData? message) async {
        final MethodCall call = codec.decodeMethodCall(message);
        if (call.method == 'listen') {
          Future.microtask(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .handlePlatformMessage(
              'apple_intelligence_flutter/stream',
              codec.encodeSuccessEnvelope({
                'done': false,
                'cumulativeText': 'Hello',
              }),
              (_) {},
            );
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .handlePlatformMessage(
              'apple_intelligence_flutter/stream',
              codec.encodeSuccessEnvelope({
                'done': false,
                'cumulativeText': 'Hello world',
              }),
              (_) {},
            );
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .handlePlatformMessage(
              'apple_intelligence_flutter/stream',
              codec.encodeSuccessEnvelope({
                'done': true,
                'cumulativeText': 'Hello world',
                'raw': '"Hello world"',
              }),
              (_) {},
            );
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .handlePlatformMessage(
              'apple_intelligence_flutter/stream',
              null,
              (_) {},
            );
          });
          return codec.encodeSuccessEnvelope(null);
        } else if (call.method == 'cancel') {
          return codec.encodeSuccessEnvelope(null);
        }
        return null;
      },
    );

    final chunks = await AppleIntelligenceClient.instance
        .streamPrompt(prompt: 'Hello world')
        .toList();

    expect(chunks, hasLength(3));
    expect(chunks.first.cumulativeText, 'Hello');
    expect(chunks[1].delta, ' world');
    expect(chunks.last.isFinal, isTrue);
    expect(chunks.last.cumulativeText, 'Hello world');
  });

  test('streamPromptSession can be stopped early', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    const MethodCodec codec = StandardMethodCodec();
    var cancelCalled = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'apple_intelligence_flutter/stream',
      (ByteData? message) async {
        final MethodCall call = codec.decodeMethodCall(message);
        if (call.method == 'listen') {
          Future.microtask(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .handlePlatformMessage(
              'apple_intelligence_flutter/stream',
              codec.encodeSuccessEnvelope({
                'done': false,
                'cumulativeText': 'Hello',
              }),
              (_) {},
            );
          });
          return codec.encodeSuccessEnvelope(null);
        } else if (call.method == 'cancel') {
          cancelCalled = true;
          return codec.encodeSuccessEnvelope(null);
        }
        return null;
      },
    );

    final session =
        AppleIntelligenceClient.instance.streamPromptSession(prompt: 'Hello');

    final captured = <AppleIntelligenceStreamChunk>[];
    final subscription = session.stream.listen(captured.add);

    await Future<void>.delayed(const Duration(milliseconds: 10));

    await session.stop();
    await session.done;
    await subscription.cancel();

    expect(cancelCalled, isTrue);
    expect(captured, hasLength(1));
    expect(captured.single.cumulativeText, 'Hello');
  });
}
