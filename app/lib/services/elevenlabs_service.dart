import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/story_options.dart';

class ElevenLabsService {
  static const _voiceIds = {
    StoryLanguage.en: 'XrExE9yKIg1WjnnlVkGX', // Matilda — warm English storyteller
    StoryLanguage.he: 'pNInz6obpgDQGcFmaJgB', // Adam — multilingual, clear Hebrew
    StoryLanguage.es: 'XB0fDUnXU5powFXDhCwa', // Charlotte — warm Spanish
  };

  static const _modelId = 'eleven_multilingual_v2';
  static const _apiBase = 'https://api.elevenlabs.io';

  final http.Client _client;
  final String _apiKey;

  ElevenLabsService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? dotenv.env['ELEVENLABS_API_KEY'] ??
            (throw ArgumentError('ELEVENLABS_API_KEY is not set in assets/.env'));

  static String voiceForLanguage(StoryLanguage language) =>
      _voiceIds[language] ??
      (throw ArgumentError('No ElevenLabs voice configured for language: $language'));

  void close() => _client.close();

  Future<Uint8List> synthesize(String text, StoryLanguage language) async {
    final voiceId = voiceForLanguage(language);
    final response = await _client.post(
      Uri.parse('$_apiBase/v1/text-to-speech/$voiceId'),
      headers: {
        'xi-api-key': _apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: jsonEncode({
        'text': text,
        'model_id': _modelId,
        'voice_settings': {'stability': 0.5, 'similarity_boost': 0.75},
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
        'ElevenLabs error ${response.statusCode}: ${response.body}',
      );
    }

    return response.bodyBytes;
  }
}
