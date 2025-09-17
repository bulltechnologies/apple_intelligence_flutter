import 'package:flutter_test/flutter_test.dart';
import 'package:apple_intelligence_flutter/apple_intelligence_flutter.dart';

void main() {
  group('AppleIntelligenceClient', () {
    test('should create singleton instance', () {
      final client1 = AppleIntelligenceClient.instance;
      final client2 = AppleIntelligenceClient.instance;

      expect(client1, equals(client2));
    });

    test('should initialize without error', () async {
      final client = AppleIntelligenceClient.instance;

      final availability = await client.initialize();

      expect(availability, isA<AppleIntelligenceAvailability>());
    });

    test('should return false for isAvailable initially', () async {
      final client = AppleIntelligenceClient.instance;

      final isAvailable = await client.isAvailable();

      expect(isAvailable, isFalse);
    });
  });

  group('TextProcessingService', () {
    late TextProcessingService service;

    setUp(() {
      service = TextProcessingService();
    });

    test('should return error response for unimplemented functionality',
        () async {
      const request = TextProcessingRequest(text: 'Test text');

      final response = await service.processText(request);

      expect(response.success, isFalse);
      expect(response.error, contains('iOS devices only'));
    });
  });

  group('TextProcessingRequest', () {
    test('should convert to JSON correctly', () {
      const request = TextProcessingRequest(
        text: 'Test text',
        context: 'Test context',
      );

      final json = request.toJson();

      expect(json['text'], equals('Test text'));
      expect(json['context'], equals('Test context'));
    });

    test('should exclude null context from JSON', () {
      const request = TextProcessingRequest(text: 'Test text');

      final json = request.toJson();

      expect(json['text'], equals('Test text'));
      expect(json.containsKey('context'), isFalse);
    });
  });

  group('TextProcessingResponse', () {
    test('should create from JSON correctly', () {
      final json = {
        'success': true,
        'error': null,
        'processedText': 'Processed text',
        'metadata': {'key': 'value'},
      };

      final response = TextProcessingResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.error, isNull);
      expect(response.processedText, equals('Processed text'));
      expect(response.metadata, equals({'key': 'value'}));
    });
  });
}
