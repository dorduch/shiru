import 'dart:convert';
import 'package:http/http.dart' as http;

class VoiceCloneService {
  static const _cartesiaApiKey = String.fromEnvironment('CARTESIA_API_KEY');
  static const _cartesiaVersion = '2025-04-16';

  static Future<String> cloneVoice({
    required String name,
    required String audioFilePath,
  }) async {
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

  static Future<void> deleteVoice(String voiceId) async {
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
