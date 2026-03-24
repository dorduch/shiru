import 'dart:convert';
import 'package:http/http.dart' as http;

class GiphyService {
  // Using a common public beta testing key for Giphy. 
  // In production, you would replace this with your own API key.
  static const String _apiKey = 'J2DQ0pjWs6zKt86smg6nbaPCDTDGQiq1'; 
  
  // Cache to store URLs so we don't spam the API for the same card
  static final Map<String, String> _cache = {};

  static Future<String?> fetchPixelArtGif(String query) async {
    if (_cache.containsKey(query)) return _cache[query];

    try {
      // We search for "pixel art" + the card title, and filter for stickers (transparent background)
      final encodedQuery = Uri.encodeComponent('pixel art $query');
      final url = Uri.parse('https://api.giphy.com/v1/stickers/search?api_key=$_apiKey&q=$encodedQuery&limit=1&rating=g');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          final gifUrl = data['data'][0]['images']['fixed_height']['url'];
          _cache[query] = gifUrl;
          return gifUrl;
        }
      }
    } catch (e) {
      print('Giphy API error: $e');
    }
    return null;
  }
}
