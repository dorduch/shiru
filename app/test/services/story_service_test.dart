import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shiru/models/story_options.dart';
import 'package:shiru/services/elevenlabs_service.dart';
import 'package:shiru/services/story_service.dart';

void main() {
  group('StoryService.buildPrompt', () {
    test('includes hero prompt name, theme prompt name, language, and word count', () {
      final prompt = StoryService.buildPrompt(
        hero: StoryHero.knight,
        theme: StoryTheme.bedtime,
        language: StoryLanguage.en,
        length: StoryLength.short,
      );
      expect(prompt, contains(StoryHero.knight.promptName));
      expect(prompt, contains(StoryTheme.bedtime.promptName));
      expect(prompt, contains(StoryLanguage.en.promptLabel));
      expect(prompt, contains(StoryLength.short.targetWordCount.toString()));
    });

    test('bedtime theme includes calming instruction', () {
      final prompt = StoryService.buildPrompt(
        hero: StoryHero.bunny,
        theme: StoryTheme.bedtime,
        language: StoryLanguage.he,
        length: StoryLength.long,
      );
      expect(prompt.toLowerCase(), contains('sleep'));
    });
  });

  group('StoryService.parseClaudeResponse', () {
    test('extracts title and story from plain JSON', () {
      const json =
          '{"title": "The Brave Knight", "story": "Once upon a time..."}';
      final result = StoryService.parseClaudeResponse(json);
      expect(result.title, 'The Brave Knight');
      expect(result.story, 'Once upon a time...');
    });

    test('extracts JSON wrapped in a markdown code block', () {
      const wrapped =
          '```json\n{"title": "A Dragon\'s Quest", "story": "Long ago..."}\n```';
      final result = StoryService.parseClaudeResponse(wrapped);
      expect(result.title, "A Dragon's Quest");
      expect(result.story, 'Long ago...');
    });

    test('throws when required fields are missing', () {
      expect(
        () => StoryService.parseClaudeResponse('{"title": "Only title"}'),
        throwsException,
      );
    });
  });

  group('StoryService.callClaudeApi', () {
    test('sends correct Anthropic headers and returns parsed story', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'content': [
              {
                'type': 'text',
                'text':
                    '{"title": "The Bold Knight", "story": "In a land far away..."}',
              }
            ],
          }),
          200,
        );
      });

      final service = StoryService(
        httpClient: client,
        anthropicApiKey: 'test-key',
        tts: ElevenLabsService(
          client: MockClient((_) async =>
              http.Response.bytes(Uint8List(0), 200)),
          apiKey: 'tts-key',
        ),
      );

      final story = await service.callClaudeApi(
        hero: StoryHero.knight,
        theme: StoryTheme.adventure,
        language: StoryLanguage.en,
        length: StoryLength.short,
      );

      expect(captured.headers['x-api-key'], 'test-key');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      expect(captured.url.toString(),
          contains('api.anthropic.com/v1/messages'));
      expect(story.title, 'The Bold Knight');
      expect(story.story, contains('land far away'));
    });

    test('throws on non-200 Claude response', () async {
      final client = MockClient(
          (_) async => http.Response('{"error": "rate limited"}', 429));

      final service = StoryService(
        httpClient: client,
        anthropicApiKey: 'test-key',
        tts: ElevenLabsService(
          client: MockClient((_) async =>
              http.Response.bytes(Uint8List(0), 200)),
          apiKey: 'tts-key',
        ),
      );

      expect(
        () => service.callClaudeApi(
          hero: StoryHero.wizard,
          theme: StoryTheme.magic,
          language: StoryLanguage.he,
          length: StoryLength.long,
        ),
        throwsException,
      );
    });
  });
}
