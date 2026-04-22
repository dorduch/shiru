import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shiru/models/story_options.dart';
import 'package:shiru/services/elevenlabs_service.dart';

void main() {
  group('ElevenLabsService', () {
    test('synthesize sends correct headers and voice path', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      });

      final service = ElevenLabsService(client: client, apiKey: 'test-key');
      final result = await service.synthesize('Hello world', StoryLanguage.en);

      expect(captured.headers['xi-api-key'], 'test-key');
      expect(captured.headers['content-type'], contains('application/json'));
      expect(
        captured.url.path,
        contains(ElevenLabsService.voiceForLanguage(StoryLanguage.en)),
      );
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['text'], 'Hello world');
      expect(body['model_id'], 'eleven_multilingual_v2');
      expect(result, equals(Uint8List.fromList([1, 2, 3])));
    });

    test('synthesize throws on non-200 response', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      final service = ElevenLabsService(client: client, apiKey: 'test-key');

      expect(
        () => service.synthesize('text', StoryLanguage.en),
        throwsException,
      );
    });

    test('each language maps to a distinct voice ID', () {
      final voices = StoryLanguage.values
          .map(ElevenLabsService.voiceForLanguage)
          .toSet();
      expect(
        voices.length,
        StoryLanguage.values.length,
        reason: 'each language should have a unique voice ID',
      );
    });

    test('Hebrew voice is used for Hebrew language', () {
      expect(
        ElevenLabsService.voiceForLanguage(StoryLanguage.he),
        isNotEmpty,
      );
    });
  });
}
