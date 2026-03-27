import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/story_builder_state.dart';

class StoryBuilderService {
  static const _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const _cartesiaApiKey = String.fromEnvironment('CARTESIA_API_KEY');
  static const _cartesiaVersion = '2025-04-16';

  static Future<({String title, String text})> generateStory({
    required String hero,
    required String theme,
    required StoryLength length,
  }) async {
    if (_openAiApiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY not configured. Pass it via --dart-define=OPENAI_API_KEY=...');
    }
    final heroLabel = storyHeroes.firstWhere((h) => h['id'] == hero)['label']!;
    final themeLabel = storyThemes.firstWhere((t) => t['id'] == theme)['label']!;
    final wordCount = length == StoryLength.short ? 150 : 400;
    final maxTokens = length == StoryLength.short ? 500 : 1200;

    final systemPrompt = '''You are a warm and engaging storyteller for children ages 3–10. You tell stories like a loving grandparent telling a bedtime story — with a warm voice, expressive language, and lots of emotion.

# The Story
- Main hero: $heroLabel
- Theme: $themeLabel
- Length: approximately $wordCount words
- Write in simple, clear English. Short sentences. Words a 4-year-old can understand.

# Structure
- Opening: Introduce the hero and their world in an inviting way
- Middle: An adventure with a surprising challenge or problem
- Climax: A suspenseful moment just before the resolution
- End: A happy ending with a small positive message (friendship, courage, imagination)

# Writing Style
- Use repetition and recurring phrases that children love (e.g., "And then... guess what happened? You won't believe it!")
- Add sounds and effects: "BOOM!", "Shhhh...", "Tick tock tick tock"
- Give characters short, lively dialogues
- Use rhetorical questions that draw the child in: "And what do you think he did?"

# Speaking Instructions (required!)
The text will be read aloud by a Cartesia text-to-speech system that supports the following tags:

**Pauses** — insert silence:
- <break time="300ms"/> — after every important sentence
- <break time="700ms"/> — before a surprising or suspenseful moment
- <break time="1.2s"/> — between story sections (opening→adventure, adventure→climax)

**Emotions** — shift the narrator's tone (place the tag just before the text it should affect):
- <emotion value="content" /> — for calm, warm narration (default)
- <emotion value="excited" /> — for adventure, discovery, joyful moments
- <emotion value="scared" /> — for suspenseful or tense moments
- <emotion value="sad" /> — for moments of loss or disappointment (resolved by the end)
- Return to <emotion value="content" /> after each emotional peak

**Other style notes:**
- When a character speaks in a whisper, write it in parentheses: (whispering) "Let's get out of here..."
- When there is a shout or excitement, use an exclamation mark: "Hooray! We did it!"
- When there is a sound effect, write it as a single word: BOOM!

# Rules
- On the first line write a short, creative title for the story (no numbering, no "Title:", just the text).
- On the second line write --- (three dashes).
- After that write the story itself.
- Do not use scary or violent words.
- Each character speaks in their own unique style.''';

    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $_openAiApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-4o',
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': 'Write the story'},
            ],
            'temperature': 0.9,
            'max_tokens': maxTokens,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Error generating story: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices'][0]['message']['content'] as String;
    final separatorIndex = content.indexOf('---');
    if (separatorIndex != -1) {
      final title = content.substring(0, separatorIndex).trim();
      final text = content.substring(separatorIndex + 3).trim();
      return (title: title, text: text);
    }
    return (title: '', text: content);
  }

  static Future<String> generateAudio(
    String storyText, {
    required String voiceId,
    double speed = 1.0,
    double volume = 1.0,
  }) async {
    if (_cartesiaApiKey.isEmpty) {
      throw Exception('CARTESIA_API_KEY not configured. Pass it via --dart-define=CARTESIA_API_KEY=...');
    }
    final requestBody = jsonEncode({
      'transcript': storyText,
      'model_id': 'sonic-3',
      'voice': {'mode': 'id', 'id': voiceId},
      'output_format': {
        'container': 'mp3',
        'bit_rate': 128000,
        'sample_rate': 44100,
      },
      'language': 'en',
      'generation_config': {
        'speed': speed,
        'volume': volume,
      },
    });
    dev.log(requestBody, name: 'CartesiaTTS');
    try {
      final logDir = await getApplicationDocumentsDirectory();
      await File('${logDir.path}/last_tts_request.json').writeAsString(requestBody);
    } catch (_) {}
    final response = await http
        .post(
          Uri.parse('https://api.cartesia.ai/tts/bytes'),
          headers: {
            'Authorization': 'Bearer $_cartesiaApiKey',
            'Cartesia-Version': _cartesiaVersion,
            'Content-Type': 'application/json',
          },
          body: requestBody,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Error generating audio: ${response.statusCode}');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}.mp3';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  static const _stockVoiceIds = [
    'e13cae5c-ec59-4f71-b0a6-266df3c9bb8e',
    'a33f7a4c-100f-41cf-a1fd-5822e8fc253f',
  ];

  /// Fetches the two pinned stock voices from Cartesia by ID.
  /// Returns an empty list on any failure so callers degrade gracefully.
  static Future<List<Map<String, String>>> loadStockVoices() async {
    if (_cartesiaApiKey.isEmpty) return [];
    try {
      final results = <Map<String, String>>[];
      for (final id in _stockVoiceIds) {
        final response = await http.get(
          Uri.parse('https://api.cartesia.ai/voices/$id'),
          headers: {
            'Authorization': 'Bearer $_cartesiaApiKey',
            'Cartesia-Version': _cartesiaVersion,
          },
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final v = jsonDecode(response.body) as Map<String, dynamic>;
        final gender = v['gender'] as String?;
        final emoji = gender == 'masculine'
            ? '👨'
            : gender == 'feminine'
                ? '👩'
                : '🎤';
        results.add({
          'id': id,
          'name': v['name'] as String,
          'emoji': emoji,
        });
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}
