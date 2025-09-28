import 'package:apple_intelligence_flutter/apple_intelligence_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('apple_intelligence_flutter');

  late TranslationService service;

  setUp(() {
    service = TranslationService(channel: channel);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('translate forwards arguments and parses response', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'translateText');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['text'], 'hello world');
      expect(args['sourceLanguage'], 'en');
      expect(args['targetLanguage'], 'es');
      expect(args['clientIdentifier'], 'sample');

      return {
        'sourceText': 'hello world',
        'targetText': 'hola mundo',
        'sourceLanguage': 'en',
        'targetLanguage': 'es',
        'clientIdentifier': 'sample',
      };
    });

    final result = await service.translate(
      text: '  hello world  ',
      sourceLanguage: ' en ',
      targetLanguage: ' es ',
      clientIdentifier: ' sample ',
    );

    expect(result.sourceText, 'hello world');
    expect(result.targetText, 'hola mundo');
    expect(result.sourceLanguage, 'en');
    expect(result.targetLanguage, 'es');
    expect(result.clientIdentifier, 'sample');
  });

  test('translate throws without touching platform when text empty', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var invoked = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      invoked = true;
      return null;
    });

    expect(
      () => service.translate(
        text: '   ',
        sourceLanguage: 'en',
        targetLanguage: 'es',
      ),
      throwsA(isA<AppleIntelligenceException>().having(
        (error) => error.code,
        'code',
        'translation_empty_text',
      )),
    );

    expect(invoked, isFalse);
  });

  test('availability returns structured status', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'translationAvailability');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['sourceLanguage'], 'en');
      expect(args['targetLanguage'], 'it');
      return {
        'status': 'supported',
        'isInstalled': false,
        'isSupported': true,
        'sourceLanguage': 'en',
        'targetLanguage': 'it',
      };
    });

    final status = await service.availability(
      sourceLanguage: ' en ',
      targetLanguage: ' it ',
    );

    expect(status.status, 'supported');
    expect(status.isInstalled, isFalse);
    expect(status.isSupported, isTrue);
    expect(status.sourceLanguage, 'en');
    expect(status.targetLanguage, 'it');
    expect(status.canDownload, isTrue);
    expect(status.canTranslate, isFalse);
  });

  test('supportedLanguages normalizes list from platform', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'translationSupportedLanguages');
      return <dynamic>[' en ', null, ''];
    });

    final languages = await service.supportedLanguages();
    expect(languages, ['en']);
  });

  test('prepareTranslation forwards sanitized arguments', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    Map<dynamic, dynamic>? capturedArgs;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'prepareTranslation');
      capturedArgs = call.arguments as Map<dynamic, dynamic>;
      return true;
    });

    await service.prepareTranslation(
      sourceLanguage: ' en ',
      targetLanguage: ' es ',
    );

    expect(capturedArgs?['sourceLanguage'], 'en');
    expect(capturedArgs?['targetLanguage'], 'es');
  });
}
