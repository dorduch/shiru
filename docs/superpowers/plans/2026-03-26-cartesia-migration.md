# Cartesia API Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all ElevenLabs API calls with Cartesia (Sonic-3) for voice cloning and TTS, with no change to app structure or user flows.

**Architecture:** In-place surgical swap — same service file names, same method signatures, same providers. Only HTTP internals, env var names, and one DB column name change. Stock voices switch from a hardcoded const list to a FutureProvider that calls `GET /voices`.

**Tech Stack:** Flutter, Dart `http` package, sqflite_sqlcipher, Riverpod

---

## Files Modified

| File | Change |
|------|--------|
| `app/android/app/src/main/res/xml/network_security_config.xml` | Replace `api.elevenlabs.io` domain with `api.cartesia.ai` |
| `app/build_release.sh` | Update error message to reference `CARTESIA_API_KEY` |
| `app/lib/services/voice_clone_service.dart` | New endpoints, headers, response field |
| `app/lib/models/voice_profile.dart` | Rename `elevenLabsVoiceId` → `voiceId` |
| `app/lib/db/database_service.dart` | Version 3→4, migration, updated schema |
| `app/lib/providers/voice_profiles_provider.dart` | Field rename references |
| `app/lib/services/story_builder_service.dart` | New TTS endpoint, add `loadStockVoices()` |
| `app/lib/models/story_builder_state.dart` | Remove const `stockVoices` list |
| `app/lib/providers/story_builder_provider.dart` | Add `stockVoicesProvider` FutureProvider |
| `app/lib/ui/story_builder_screen.dart` | Watch `stockVoicesProvider` instead of const |

---

### Task 1: Config — network security and build script

**Files:**
- Modify: `app/android/app/src/main/res/xml/network_security_config.xml`
- Modify: `app/build_release.sh`

- [ ] **Step 1: Update network_security_config.xml**

Replace the ElevenLabs domain-config block (lines 37–43) with Cartesia:

```xml
    <!-- Cartesia API — enforce HTTPS, trust system CAs -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.cartesia.ai</domain>
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </domain-config>
```

The full file after change:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!--
    Network Security Configuration for Shiru.

    Global policy: cleartext (plain HTTP) traffic is disallowed. All connections
    must use TLS, which is enforced by the Android network stack for API 28+.

    The system CA store is trusted by default for all domains, so no explicit
    <trust-anchors> block is needed here.

    TODO before production release: add <pin-set> blocks under each <domain-config>
    to enable certificate pinning. Obtain the SHA-256 SPKI fingerprints for each
    domain's current and backup certificates using:
        openssl s_client -connect <host>:443 | openssl x509 -pubkey -noout \
          | openssl pkey -pubin -outform der \
          | openssl dgst -sha256 -binary | base64
    Then add them as:
        <pin digest="SHA-256">base64encodedHash=</pin>
-->
<network-security-config>

    <!-- Block all cleartext traffic app-wide -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </base-config>

    <!-- OpenAI API — enforce HTTPS, trust system CAs -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.openai.com</domain>
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </domain-config>

    <!-- Cartesia API — enforce HTTPS, trust system CAs -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.cartesia.ai</domain>
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </domain-config>

    <!-- Giphy API — enforce HTTPS, trust system CAs -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.giphy.com</domain>
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </domain-config>

</network-security-config>
```

- [ ] **Step 2: Update build_release.sh error message**

Change line 8 from:
```bash
  echo "Error: env.json not found. Create it with OPENAI_API_KEY, ELEVENLABS_API_KEY, GIPHY_API_KEY."
```
To:
```bash
  echo "Error: env.json not found. Create it with OPENAI_API_KEY, CARTESIA_API_KEY, GIPHY_API_KEY."
```

- [ ] **Step 3: Update your local env.json**

Rename the key in your local (gitignored) `app/env.json`:
```json
{
  "OPENAI_API_KEY": "sk-proj-...",
  "CARTESIA_API_KEY": "sk_car_...",
  "GIPHY_API_KEY": "..."
}
```

- [ ] **Step 4: Commit**

```bash
cd app
git add android/app/src/main/res/xml/network_security_config.xml build_release.sh
git commit -m "config: replace ElevenLabs domain with Cartesia in network security and build script"
```

---

### Task 2: Update VoiceCloneService

**Files:**
- Modify: `app/lib/services/voice_clone_service.dart`

Cartesia differences from ElevenLabs:
- Endpoint: `POST https://api.cartesia.ai/voices/clone` (was `/v1/voices/add`)
- Auth header: `Authorization: Bearer <key>` (was `xi-api-key: <key>`)
- Required header: `Cartesia-Version: 2025-04-16`
- Multipart field name: `clip` (was `files`)
- Extra required field: `language: "en"`
- Response: `{ "id": "..." }` (was `{ "voice_id": "..." }`)
- Delete response: `204` (was `200`)
- Delete endpoint: `DELETE https://api.cartesia.ai/voices/{id}` (same path shape)

- [ ] **Step 1: Replace voice_clone_service.dart**

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/voice_clone_service.dart
git commit -m "feat: migrate VoiceCloneService from ElevenLabs to Cartesia"
```

---

### Task 3: Rename VoiceProfile field

**Files:**
- Modify: `app/lib/models/voice_profile.dart`

Rename `elevenLabsVoiceId` → `voiceId` throughout. The DB column will also change (handled in Task 4), so `fromMap`/`toMap` must read/write `voice_id`.

- [ ] **Step 1: Replace voice_profile.dart**

```dart
class VoiceProfile {
  final String id;
  final String name;
  final String voiceId;
  final String? samplePath;
  final int createdAt;

  VoiceProfile({
    required this.id,
    required this.name,
    required this.voiceId,
    this.samplePath,
    required this.createdAt,
  });

  factory VoiceProfile.fromMap(Map<String, dynamic> map) {
    return VoiceProfile(
      id: map['id'],
      name: map['name'],
      voiceId: map['voice_id'],
      samplePath: map['sample_path'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'voice_id': voiceId,
      'sample_path': samplePath,
      'created_at': createdAt,
    };
  }

  VoiceProfile copyWith({
    String? name,
    String? voiceId,
    String? samplePath,
  }) {
    return VoiceProfile(
      id: id,
      name: name ?? this.name,
      voiceId: voiceId ?? this.voiceId,
      samplePath: samplePath ?? this.samplePath,
      createdAt: createdAt,
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/voice_profile.dart
git commit -m "refactor: rename VoiceProfile.elevenLabsVoiceId to voiceId"
```

---

### Task 4: Database migration v3 → v4

**Files:**
- Modify: `app/lib/db/database_service.dart`

Three changes:
1. `_createDB` — fresh installs get `voice_id` column (not `elevenlabs_voice_id`)
2. `_upgradeDB` — new block migrates existing data via table recreation
3. Both `openDatabase` calls with `version: 3` → `version: 4`

- [ ] **Step 1: Update `_createDB` voice_profiles table definition**

Find the CREATE TABLE voice_profiles block inside `_createDB` (around line 152) and replace it:

```dart
    await db.execute('''
CREATE TABLE voice_profiles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  voice_id TEXT NOT NULL,
  sample_path TEXT,
  created_at INTEGER NOT NULL
)
''');
```

- [ ] **Step 2: Add v4 migration block to `_upgradeDB`**

Add after the existing `if (oldVersion < 3)` block:

```dart
    if (oldVersion < 4) {
      await db.execute('''
CREATE TABLE voice_profiles_new (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  voice_id TEXT NOT NULL,
  sample_path TEXT,
  created_at INTEGER NOT NULL
)
''');
      await db.execute('''
INSERT INTO voice_profiles_new
SELECT id, name, elevenlabs_voice_id, sample_path, created_at
FROM voice_profiles
''');
      await db.execute('DROP TABLE voice_profiles');
      await db.execute('ALTER TABLE voice_profiles_new RENAME TO voice_profiles');
    }
```

- [ ] **Step 3: Bump version numbers to 4**

There are **three** `openDatabase` calls with `version: 3` in `_initDB` — all must become `version: 4`:
1. The `if (!fileExists)` fresh-install branch (~line 57)
2. The `try` existing-encrypted-DB branch (~line 70)
3. The legacy migration new-DB branch (~line 103)

Change all three:

```dart
      return await openDatabase(
        path,
        version: 4,
        password: password,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
```

The legacy migration path (the third one) has no `onUpgrade` — that's correct, leave it as-is; `_createDB` will create the fresh schema with `voice_id`.

- [ ] **Step 4: Update voice_profiles create statement in `_upgradeDB` `oldVersion < 3` block**

The `< 3` block (around line 174) creates `voice_profiles` for upgrades from v1/v2. It will be immediately followed by the `< 4` block which migrates the column, but for consistency, it doesn't need to change — the rename migration handles it.

No change needed to the `< 3` block.

- [ ] **Step 5: Commit**

```bash
git add lib/db/database_service.dart
git commit -m "feat: db migration v4 — rename elevenlabs_voice_id to voice_id in voice_profiles"
```

---

### Task 5: Update VoiceProfilesProvider

**Files:**
- Modify: `app/lib/providers/voice_profiles_provider.dart`

Two references to the old field name:
- Line 29: `elevenLabsVoiceId: voiceId` → `voiceId: voiceId`
- Line 40: `profile.elevenLabsVoiceId` → `profile.voiceId`

- [ ] **Step 1: Replace voice_profiles_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/voice_profile.dart';
import '../db/database_service.dart';
import '../services/voice_clone_service.dart';

class VoiceProfilesNotifier extends StateNotifier<AsyncValue<List<VoiceProfile>>> {
  VoiceProfilesNotifier() : super(const AsyncValue.loading()) {
    loadProfiles();
  }

  Future<void> loadProfiles() async {
    try {
      final profiles = await DatabaseService.instance.readAllVoiceProfiles();
      state = AsyncValue.data(profiles);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addProfile(String name, String audioFilePath) async {
    final voiceId = await VoiceCloneService.cloneVoice(
      name: name,
      audioFilePath: audioFilePath,
    );
    final profile = VoiceProfile(
      id: const Uuid().v4(),
      name: name,
      voiceId: voiceId,
      samplePath: audioFilePath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseService.instance.createVoiceProfile(profile);
    await loadProfiles();
  }

  Future<void> deleteProfile(String id) async {
    final profiles = state.value ?? [];
    final profile = profiles.firstWhere((p) => p.id == id);
    await VoiceCloneService.deleteVoice(profile.voiceId);
    await DatabaseService.instance.deleteVoiceProfile(id);
    await loadProfiles();
  }
}

final voiceProfilesProvider = StateNotifierProvider<VoiceProfilesNotifier, AsyncValue<List<VoiceProfile>>>((ref) {
  return VoiceProfilesNotifier();
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/voice_profiles_provider.dart
git commit -m "refactor: update VoiceProfilesProvider to use VoiceProfile.voiceId"
```

---

### Task 6: Update StoryBuilderService — TTS and stock voices

**Files:**
- Modify: `app/lib/services/story_builder_service.dart`

Changes:
- Rename `_elevenLabsApiKey` → `_cartesiaApiKey`
- Add `_cartesiaVersion` constant
- Remove dead `_voiceIds` list (never used by any method)
- Update `generateAudio()`: new endpoint (voice ID in body, not URL), new headers, new body shape
- Add `loadStockVoices()` static method that calls `GET /voices`

`generateAudio` body changes:
- Was: `{ text, model_id: "eleven_v3", voice_settings: { stability, similarity_boost } }` sent to `.../text-to-speech/{voiceId}`
- Now: `{ transcript, model_id: "sonic-3", voice: { mode: "id", id: voiceId }, output_format: { container: "mp3", bit_rate: 128, sample_rate: 44100 }, language: "en" }` sent to `https://api.cartesia.ai/tts/bytes`

Note: `<break time="..."/>` SSML tags in story text are compatible with Cartesia — no changes to `generateStory()`.

- [ ] **Step 1: Replace the Cartesia-specific parts of story_builder_service.dart**

Replace the entire file with:

```dart
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

  static Future<String> generateAudio(String storyText, {required String voiceId}) async {
    if (_cartesiaApiKey.isEmpty) {
      throw Exception('CARTESIA_API_KEY not configured. Pass it via --dart-define=CARTESIA_API_KEY=...');
    }
    final response = await http
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
              'bit_rate': 128,
              'sample_rate': 44100,
            },
            'language': 'en',
          }),
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

  /// Fetches up to 6 English voices from Cartesia's public voice library.
  /// Returns an empty list on any failure so callers degrade gracefully.
  static Future<List<Map<String, String>>> loadStockVoices() async {
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
        voices = (decoded as Map<String, dynamic>)['data'] as List<dynamic>;
      }

      return voices.map((v) {
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/story_builder_service.dart
git commit -m "feat: migrate StoryBuilderService TTS from ElevenLabs to Cartesia Sonic-3"
```

---

### Task 7: Remove const stockVoices and add FutureProvider

**Files:**
- Modify: `app/lib/models/story_builder_state.dart`
- Modify: `app/lib/providers/story_builder_provider.dart`

The const `stockVoices` list in `story_builder_state.dart` is hardcoded with ElevenLabs IDs. Remove it — the story builder screen will watch a `FutureProvider` instead.

- [ ] **Step 1: Remove const stockVoices from story_builder_state.dart**

Delete these lines (33–40):
```dart
const List<Map<String, String>> stockVoices = [
  {'id': 'EXAVITQu4vr4xnSDxMaL', 'name': 'Sarah', 'emoji': '👩'},
  {'id': '21m00Tcm4TlvDq8ikWAM', 'name': 'Rachel', 'emoji': '👩‍🦰'},
  {'id': 'ErXwobaYiN019PkySvjV', 'name': 'Antoni', 'emoji': '👨'},
  {'id': 'TxGEqnHWrfWFTfGW9XjX', 'name': 'Josh', 'emoji': '👨‍🦱'},
  {'id': 'onwK4e9ZLuTAKqWW03F9', 'name': 'Daniel', 'emoji': '👨'},
  {'id': 'XB0fDUnXU5powFXDhCwa', 'name': 'Charlotte', 'emoji': '👩‍🦳'},
];
```

- [ ] **Step 2: Add stockVoicesProvider to story_builder_provider.dart**

Add at the bottom of `story_builder_provider.dart`, after the existing `storyBuilderProvider`:

```dart
/// Fetches Cartesia stock voices once and caches for the app session.
final stockVoicesProvider = FutureProvider<List<Map<String, String>>>((ref) {
  return StoryBuilderService.loadStockVoices();
});
```

Also add the import at the top of `story_builder_provider.dart` if not already present:
```dart
import '../services/story_builder_service.dart';
```
(It's already imported on line 5 — no change needed.)

- [ ] **Step 3: Commit**

```bash
git add lib/models/story_builder_state.dart lib/providers/story_builder_provider.dart
git commit -m "feat: replace hardcoded ElevenLabs stock voice IDs with Cartesia FutureProvider"
```

---

### Task 8: Update StoryBuilderScreen voice selection

**Files:**
- Modify: `app/lib/ui/story_builder_screen.dart`

The voice selection section currently reads:
```dart
itemCount: stockVoices.length,
...
final voice = stockVoices[index];
```

Replace this GridView section with one that watches `stockVoicesProvider`. Add the provider import.

- [ ] **Step 1: Add stockVoicesProvider import**

`story_builder_screen.dart` already imports `story_builder_provider.dart` (for `storyBuilderProvider`). The new `stockVoicesProvider` is in the same file, so no new import is needed.

Remove the import of `story_builder_state.dart`'s `stockVoices` — it no longer exists. Check the current imports at the top of the screen file and remove any that only served the `stockVoices` const.

The import `import '../models/story_builder_state.dart';` is still needed for `StoryBuilderStep`, `storyHeroes`, `storyThemes`, `heroColors`, `StoryLength` — keep it.

- [ ] **Step 2: Replace the stock voices GridView section**

Find the section around line 284 that renders stock voices:

```dart
GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: stockVoices.length,
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
    childAspectRatio: 1.2,
  ),
  itemBuilder: (context, index) {
    final voice = stockVoices[index];
    return StoryOptionCard(
      emoji: voice['emoji']!,
      label: voice['name']!,
      onTap: () {
        HapticFeedback.mediumImpact();
        notifier.selectVoice(voice['id']!);
      },
    );
  },
),
```

Replace with:

```dart
ref.watch(stockVoicesProvider).when(
  loading: () => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: CircularProgressIndicator(),
    ),
  ),
  error: (_, __) => const SizedBox.shrink(),
  data: (voices) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: voices.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
    ),
    itemBuilder: (context, index) {
      final voice = voices[index];
      return StoryOptionCard(
        emoji: voice['emoji']!,
        label: voice['name']!,
        onTap: () {
          HapticFeedback.mediumImpact();
          notifier.selectVoice(voice['id']!);
        },
      );
    },
  ),
),
```

- [ ] **Step 3: Run analyze**

```bash
cd app
flutter analyze
```

Expected: no errors. Fix any type errors reported.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/story_builder_screen.dart
git commit -m "feat: load Cartesia stock voices dynamically in story builder voice selection"
```

---

## Verification Checklist

Run all checks from the `app/` directory.

- [ ] **Build succeeds**
  ```bash
  flutter pub get
  flutter analyze
  flutter build apk --dart-define-from-file=env.json
  ```
  Expected: zero errors, APK builds successfully.

- [ ] **Voice cloning** — parent flow end-to-end
  1. Open app → tap PIN → enter `1234`
  2. Navigate to Voices → Add Voice
  3. Enter a name, record ~10s of speech, tap Use Recording
  4. Processing screen appears, then success
  5. Profile appears in voice list
  6. Verify voice appears in [Cartesia dashboard](https://play.cartesia.ai)

- [ ] **Voice deletion**
  1. Delete a voice profile from the list
  2. Verify it's removed from Cartesia dashboard

- [ ] **TTS with cloned voice**
  1. Story Builder → choose any hero/theme → select a family voice → Short
  2. Audio plays, pauses at `<break>` points work correctly

- [ ] **TTS with stock voice**
  1. Story Builder → choose any hero/theme → select a stock voice (loaded from Cartesia) → Short
  2. Audio generates and plays

- [ ] **Stock voices load**
  1. Story Builder → voice selection step
  2. Brief loading spinner, then up to 6 Cartesia voices appear with correct names

- [ ] **DB migration — upgrade path**
  1. Install an old build (with `elevenlabs_voice_id`) that has saved voice profiles
  2. Install the new build over it
  3. Voice profiles still appear with correct names

- [ ] **DB migration — fresh install**
  1. Clean install of new build
  2. Add a voice profile, restart app
  3. Profile persists correctly
