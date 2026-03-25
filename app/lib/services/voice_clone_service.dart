import 'dart:convert';
import 'package:http/http.dart' as http;

class VoiceCloneService {
  static const _elevenLabsApiKey = String.fromEnvironment('ELEVENLABS_API_KEY');

  static Future<String> cloneVoice({
    required String name,
    required String audioFilePath,
  }) async {
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
  }

  static Future<void> deleteVoice(String voiceId) async {
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
  }
}
