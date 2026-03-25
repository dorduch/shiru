import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/story_builder_state.dart';

class StoryBuilderService {
  static String get _openAiApiKey => dotenv.env['OPENAI_API_KEY']!;
  static String get _elevenLabsApiKey => dotenv.env['ELEVENLABS_API_KEY']!;
  static const List<String> _voiceIds = [
    'EXAVITQu4vr4xnSDxMaL', // Sarah
    '21m00Tcm4TlvDq8ikWAM', // Rachel
    'ErXwobaYiN019PkySvjV', // Antoni
    'TxGEqnHWrfWFTfGW9XjX', // Josh
    'onwK4e9ZLuTAKqWW03F9', // Daniel
    'XB0fDUnXU5powFXDhCwa', // Charlotte
  ];

  static Future<({String title, String text})> generateStory({
    required String hero,
    required String theme,
    required StoryLength length,
  }) async {
    final heroLabel = storyHeroes.firstWhere((h) => h['id'] == hero)['label']!;
    final themeLabel = storyThemes.firstWhere((t) => t['id'] == theme)['label']!;
    final wordCount = length == StoryLength.short ? 150 : 400;
    final maxTokens = length == StoryLength.short ? 500 : 1200;

    final systemPrompt = '''אתה מספר סיפורים חם ומרתק לילדים בגילאי 3-10. אתה מספר כמו סבא אוהב שמספר סיפור לפני השינה — עם קול חם, ביטויים מוגזמים, והמון רגש.

# הסיפור
- גיבור ראשי: $heroLabel
- נושא: $themeLabel
- אורך: כ-$wordCount מילים
- כתוב בעברית פשוטה וברורה. משפטים קצרים. מילים שילד בן 4 מבין.

# מבנה
- פתיחה: הצג את הגיבור והעולם שלו בצורה מזמינה
- אמצע: הרפתקה עם אתגר או בעיה מפתיעה
- שיא: רגע מותח לפני הפתרון
- סוף: סיום שמח עם מסר חיובי קטן (חברות, אומץ, דמיון)

# סגנון כתיבה
- השתמש בחזרות וביטויים חוזרים שילדים אוהבים (למשל: "ואז... מה קרה? לא תאמינו!")
- הוסף צלילים ואפקטים: "בּוּם!", "שׁשׁשׁ...", "טיק טק טיק טק"
- תן לדמויות דיאלוגים קצרים וחיים
- השתמש בשאלות רטוריות שמושכות את הילד: "ומה אתם חושבים שהוא עשה?"

# הוראות דיבור (חובה!)
הטקסט ייקרא בקול על ידי מערכת טקסט-לדיבור. חובה להוסיף את ההוראות הבאות בתוך הטקסט:
- <break time="300ms"/> — אחרי כל משפט חשוב, לתת לילד לעכל
- <break time="700ms"/> — לפני רגע מפתיע או מותח ("ופתאום..." <break time="700ms"/>)
- <break time="1.2s"/> — בין חלקי הסיפור (פתיחה→הרפתקה, הרפתקה→שיא)
- כשדמות מדברת בלחישה, כתוב את זה בסוגריים: (בלחישה) "בואו נברח מפה..."
- כשיש צעקה או התרגשות, השתמש בסימן קריאה: "הידד! הצלחנו!"
- כשיש צליל או אפקט, כתוב אותו כמילה בודדת עם הפסקה אחריו: בּוּם! <break time="500ms"/>

# חוקים
- בשורה הראשונה כתוב כותרת יצירתית וקצרה לסיפור (בלי מספור, בלי "כותרת:", רק הטקסט).
- בשורה השנייה כתוב --- (שלוש מקפים).
- אחרי זה כתוב את הסיפור עצמו.
- אל תשתמש במילים מפחידות או אלימות.
- כל דמות מדברת בסגנון ייחודי לה.''';

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
              {'role': 'user', 'content': 'כתוב את הסיפור'},
            ],
            'temperature': 0.9,
            'max_tokens': maxTokens,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('שגיאה ביצירת הסיפור: ${response.statusCode}');
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

  static Future<String> generateAudio(String storyText) async {
    final response = await http
        .post(
          Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/${_voiceIds[Random().nextInt(_voiceIds.length)]}'),
          headers: {
            'xi-api-key': _elevenLabsApiKey,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': storyText,
            'model_id': 'eleven_v3',
            'voice_settings': {
              'stability': 0.5,
              'similarity_boost': 0.75,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('שגיאה ביצירת הקול: ${response.statusCode}');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}.mp3';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }
}
