import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/story_builder_state.dart';

class StoryBuilderService {
  static const _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const _cartesiaApiKey = String.fromEnvironment('CARTESIA_API_KEY');
  static const _cartesiaVersion = '2025-04-16';
  static const _elevenLabsApiKey = String.fromEnvironment('ELEVENLABS_API_KEY');

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
The text will be read aloud by a text-to-speech system. You must include the following instructions within the text:
- <break time="300ms"/> — after every important sentence, to let the child absorb it
- <break time="700ms"/> — before a surprising or suspenseful moment ("And suddenly..." <break time="700ms"/>)
- <break time="1.2s"/> — between story sections (opening→adventure, adventure→climax)
- When a character speaks in a whisper, write it in parentheses: (whispering) "Let's get out of here..."
- When there is a shout or excitement, use an exclamation mark: "Hooray! We did it!"
- When there is a sound or effect, write it as a single word followed by a pause: BOOM! <break time="500ms"/>

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
    required TtsProvider provider,
  }) async {
    final http.Response response;
    if (provider == TtsProvider.elevenlabs) {
      if (_elevenLabsApiKey.isEmpty) {
        throw Exception('ELEVENLABS_API_KEY not configured. Pass it via --dart-define=ELEVENLABS_API_KEY=...');
      }
      response = await http
          .post(
            Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId'),
            headers: {
              'xi-api-key': _elevenLabsApiKey,
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
            },
            body: jsonEncode({
              'text': storyText,
              'model_id': 'eleven_v3',
              'voice_settings': {'stability': 0.5, 'similarity_boost': 0.75},
            }),
          )
          .timeout(const Duration(seconds: 60));
    } else {
      if (_cartesiaApiKey.isEmpty) {
        throw Exception('CARTESIA_API_KEY not configured. Pass it via --dart-define=CARTESIA_API_KEY=...');
      }
      response = await http
          .post(
            Uri.parse('https://api.cartesia.ai/tts/bytes'),
            headers: {
              'Authorization': 'Bearer $_cartesiaApiKey',
              'Cartesia-Version': _cartesiaVersion,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'transcript': storyText,
              'model_id': 'sonic-3',
              'voice': {'mode': 'id', 'id': voiceId},
              'output_format': {
                'container': 'mp3',
                'bit_rate': 128000,
                'sample_rate': 44100,
              },
              'language': 'en',
            }),
          )
          .timeout(const Duration(seconds: 60));
    }

    if (response.statusCode != 200) {
      throw Exception('Error generating audio: ${response.statusCode}');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}.mp3';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  /// Returns stock voices for the given provider.
  /// For ElevenLabs returns the hardcoded list; for Cartesia fetches dynamically.
  /// Returns an empty list on any failure so callers degrade gracefully.
  static Future<List<Map<String, String>>> loadStockVoices(TtsProvider provider) async {
    if (provider == TtsProvider.elevenlabs) {
      return List<Map<String, String>>.from(elevenLabsStockVoices);
    }

    if (_cartesiaApiKey.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse('https://api.cartesia.ai/voices?language=en&limit=6'),
        headers: {
          'Authorization': 'Bearer $_cartesiaApiKey',
          'Cartesia-Version': _cartesiaVersion,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      final List<dynamic> voices;
      if (decoded is List) {
        voices = decoded;
      } else {
        final data = (decoded as Map<String, dynamic>)['data'];
        if (data is! List) return [];
        voices = data;
      }

      return voices.take(6).map((v) {
        final gender = v['gender'] as String?;
        final emoji = gender == 'masculine'
            ? '👨'
            : gender == 'feminine'
                ? '👩'
                : '🎤';
        return {
          'id': v['id'] as String,
          'name': v['name'] as String,
          'emoji': emoji,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
