import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/story_builder_state.dart';

class VoiceCloneService {
  static const _cartesiaApiKey = String.fromEnvironment('CARTESIA_API_KEY');
  static const _cartesiaVersion = '2025-04-16';
  static const _elevenLabsApiKey = String.fromEnvironment('ELEVENLABS_API_KEY');

  static Future<String> cloneVoice({
    required String name,
    required String audioFilePath,
    required TtsProvider provider,
  }) async {
    if (provider == TtsProvider.elevenlabs) {
      if (_elevenLabsApiKey.isEmpty) {
        throw Exception('ELEVENLABS_API_KEY not configured. Pass it via --dart-define=ELEVENLABS_API_KEY=...');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.elevenlabs.io/v1/voices/add'),
      );
      request.headers['xi-api-key'] = _elevenLabsApiKey;
      request.fields['name'] = name;
      request.files.add(await http.MultipartFile.fromPath('files', audioFilePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Error cloning voice: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['voice_id'] as String;
    } else {
      if (_cartesiaApiKey.isEmpty) {
        throw Exception('CARTESIA_API_KEY not configured. Pass it via --dart-define=CARTESIA_API_KEY=...');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cartesia.ai/voices/clone'),
      );
      request.headers['Authorization'] = 'Bearer $_cartesiaApiKey';
      request.headers['Cartesia-Version'] = _cartesiaVersion;
      request.fields['name'] = name;
      request.fields['language'] = 'en';
      request.files.add(await http.MultipartFile.fromPath('clip', audioFilePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Error cloning voice: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['id'] as String;
    }
  }

  static Future<void> deleteVoice(String voiceId, {required TtsProvider provider}) async {
    if (provider == TtsProvider.elevenlabs) {
      if (_elevenLabsApiKey.isEmpty) {
        throw Exception('ELEVENLABS_API_KEY not configured. Pass it via --dart-define=ELEVENLABS_API_KEY=...');
      }

      final response = await http.delete(
        Uri.parse('https://api.elevenlabs.io/v1/voices/$voiceId'),
        headers: {'xi-api-key': _elevenLabsApiKey},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception('Error deleting voice: ${response.statusCode}');
      }
    } else {
      if (_cartesiaApiKey.isEmpty) {
        throw Exception('CARTESIA_API_KEY not configured. Pass it via --dart-define=CARTESIA_API_KEY=...');
      }

      final response = await http.delete(
        Uri.parse('https://api.cartesia.ai/voices/$voiceId'),
        headers: {
          'Authorization': 'Bearer $_cartesiaApiKey',
          'Cartesia-Version': _cartesiaVersion,
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 204) {
        throw Exception('Error deleting voice: ${response.statusCode}');
      }
    }
  }
}
