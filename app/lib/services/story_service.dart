import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_card.dart';
import '../models/sprites.dart';
import '../models/story_options.dart';
import 'elevenlabs_service.dart';
import 'library_import_service.dart';

typedef StoryContent = ({String title, String story});

class StoryService {
  static const _anthropicBase = 'https://api.anthropic.com';
  static const _anthropicVersion = '2023-06-01';
  static const _model = 'claude-haiku-4-5-20251001';

  final http.Client _httpClient;
  final ElevenLabsService _tts;
  final String _anthropicApiKey;

  StoryService({
    http.Client? httpClient,
    ElevenLabsService? tts,
    String? anthropicApiKey,
  })  : _httpClient = httpClient ?? http.Client(),
        _tts = tts ?? ElevenLabsService(),
        _anthropicApiKey =
            anthropicApiKey ?? dotenv.env['ANTHROPIC_API_KEY'] ??
            (throw ArgumentError('ANTHROPIC_API_KEY is not set in assets/.env'));

  static String buildPrompt({
    required StoryHero hero,
    required StoryTheme theme,
    required StoryLanguage language,
    required StoryLength length,
  }) {
    final bedtimeExtra = theme == StoryTheme.bedtime
        ? 'Make the ending calm and sleepy, perfect for falling asleep.'
        : '';
    return '''Write a children\'s story in ${language.promptLabel} for children aged 3–10.
The story features a ${hero.promptName} in a ${theme.promptName}.
The story should be approximately ${length.targetWordCount} words long.
$bedtimeExtra
Respond ONLY with a valid JSON object — no other text:
{"title": "...", "story": "..."}''';
  }

  static StoryContent parseClaudeResponse(String text) {
    String jsonText = text;

    // Strip markdown code block if present
    final codeBlock =
        RegExp(r'```(?:json)?\n?([\s\S]*?)\n?```').firstMatch(text);
    if (codeBlock != null) {
      jsonText = codeBlock.group(1)!;
    }

    // Extract the outermost JSON object
    final jsonObject = RegExp(r'\{[\s\S]*\}').firstMatch(jsonText);
    if (jsonObject != null) {
      jsonText = jsonObject.group(0)!;
    }

    final Map<String, dynamic> parsed = jsonDecode(jsonText);
    if (!parsed.containsKey('title') || !parsed.containsKey('story')) {
      throw Exception('Claude response missing title or story field: $text');
    }

    return (
      title: parsed['title'] as String,
      story: parsed['story'] as String,
    );
  }

  Future<StoryContent> callClaudeApi({
    required StoryHero hero,
    required StoryTheme theme,
    required StoryLanguage language,
    required StoryLength length,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$_anthropicBase/v1/messages'),
      headers: {
        'x-api-key': _anthropicApiKey,
        'anthropic-version': _anthropicVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 2048,
        'messages': [
          {
            'role': 'user',
            'content': buildPrompt(
              hero: hero,
              theme: theme,
              language: language,
              length: length,
            ),
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Claude API error ${response.statusCode}: ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = body['content'] as List<dynamic>;
    final textItem = content.firstWhere(
      (c) => (c as Map)['type'] == 'text',
      orElse: () => throw Exception('No text content in Claude response'),
    );
    return parseClaudeResponse(textItem['text'] as String);
  }

  Future<AudioCard> generate({
    required StoryHero hero,
    required StoryTheme theme,
    required StoryLanguage language,
    required StoryLength length,
    required int cardPosition,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Writing story…');
    final content = await callClaudeApi(
      hero: hero,
      theme: theme,
      language: language,
      length: length,
    );

    onStatus?.call('Converting to audio…');
    final audioBytes = await _tts.synthesize(content.story, language);

    onStatus?.call('Saving to library…');
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/${const Uuid().v4()}.mp3';
    await File(tempPath).writeAsBytes(audioBytes);

    // importAudioToLibrary copies the file and auto-deletes the temp source
    final audioPath = await LibraryImportService.importAudioToLibrary(tempPath);
    final spriteDef = autoAssignSprite(content.title);

    return AudioCard(
      id: const Uuid().v4(),
      title: content.title,
      color: theme.color,
      spriteKey: spriteDef.id,
      audioPath: audioPath,
      position: cardPosition,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
