# AI-Generated Stories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a parent-facing "Generate Story" wizard that uses Claude to write a children's story and ElevenLabs to convert it to audio, then saves it as a playable card in the library.

**Architecture:** 4 new files (StoryOptions model, ElevenLabsService, StoryService, wizard screen) + 5 modified files. StoryService orchestrates Claude API → ElevenLabs API → file import → AudioCard. The wizard is a 3-step ConsumerStatefulWidget; no new Riverpod provider needed.

**Tech Stack:** Flutter/Dart, flutter_riverpod, http, flutter_dotenv, Claude API (claude-haiku-4-5-20251001), ElevenLabs API (eleven_multilingual_v2), existing LibraryImportService + cardsProvider.

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Create | `app/assets/.env` | API keys loaded at runtime via flutter_dotenv |
| Modify | `app/pubspec.yaml` | Add `http`, `flutter_dotenv`; register `assets/.env` |
| Modify | `app/lib/main.dart` | Call `dotenv.load()` at startup |
| Create | `app/lib/models/story_options.dart` | StoryHero, StoryTheme, StoryLanguage, StoryLength enums |
| Create | `app/test/models/story_options_test.dart` | Unit tests for enums |
| Create | `app/lib/services/elevenlabs_service.dart` | ElevenLabs TTS HTTP wrapper |
| Create | `app/test/services/elevenlabs_service_test.dart` | Unit tests with MockClient |
| Create | `app/lib/services/story_service.dart` | Orchestrates Claude → ElevenLabs → card creation |
| Create | `app/test/services/story_service_test.dart` | Unit tests for prompt + parsing + API call |
| Create | `app/lib/ui/parent_generate_story_screen.dart` | 3-step wizard UI |
| Modify | `app/lib/router.dart` | Add `/parent/generate-story` route |
| Modify | `app/lib/ui/parent_list_screen.dart` | Add ✨ Generate Story button to `_LibraryHeader` |

---

## Task 1: Add dependencies and configure API keys

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/assets/.env`
- Modify: `app/lib/main.dart`

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Open `app/pubspec.yaml`. After the `wakelock_plus` line, add two new dependencies:

```yaml
  wakelock_plus: ^1.5.1
  http: ^1.2.0
  flutter_dotenv: ^5.2.1
  firebase_core: ^4.6.0
```

Also add `assets/.env` to the flutter assets list:

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/images/app_icon.png
    - assets/.env
```

- [ ] **Step 2: Create `app/assets/.env`**

Create the file `app/assets/.env` with your API keys (never commit real keys — this file is gitignored):

```
OPENAI_API_KEY=<your-openai-key>
ELEVENLABS_API_KEY=<your-elevenlabs-key>
GIPHY_API_KEY=<your-giphy-key>
ANTHROPIC_API_KEY=<your-anthropic-key>
```

- [ ] **Step 3: Load dotenv in main.dart**

Add the dotenv import and load call. In `app/lib/main.dart`, add the import at the top:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
```

Then add `await dotenv.load(fileName: 'assets/.env');` as the **first line** inside `main()`, immediately after `WidgetsFlutterBinding.ensureInitialized();`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ... rest of main unchanged
```

- [ ] **Step 4: Run flutter pub get**

```bash
cd app && flutter pub get
```

Expected: resolves packages without errors, `pubspec.lock` updated.

- [ ] **Step 5: Verify compile**

```bash
cd app && flutter analyze
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
cd app && git add pubspec.yaml pubspec.lock lib/main.dart && git commit -m "feat: add http, flutter_dotenv and configure API keys"
```

---

## Task 2: Create StoryOptions model

**Files:**
- Create: `app/lib/models/story_options.dart`
- Create: `app/test/models/story_options_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `app/test/models/story_options_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/story_options.dart';

void main() {
  group('StoryHero', () {
    test('has 10 values', () => expect(StoryHero.values.length, 10));
    test('knight has displayName, emoji, promptName', () {
      expect(StoryHero.knight.displayName, isNotEmpty);
      expect(StoryHero.knight.emoji, isNotEmpty);
      expect(StoryHero.knight.promptName, isNotEmpty);
    });
  });

  group('StoryTheme', () {
    test('has 10 values', () => expect(StoryTheme.values.length, 10));
    test('bedtime has color', () {
      expect(StoryTheme.bedtime.color, startsWith('#'));
    });
    test('every theme has a non-empty color', () {
      for (final t in StoryTheme.values) {
        expect(t.color, isNotEmpty, reason: '${t.name} missing color');
      }
    });
  });

  group('StoryLanguage', () {
    test('has 3 values', () => expect(StoryLanguage.values.length, 3));
    test('he has flag and promptLabel', () {
      expect(StoryLanguage.he.flag, isNotEmpty);
      expect(StoryLanguage.he.promptLabel, 'Hebrew');
    });
  });

  group('StoryLength', () {
    test('short targetWordCount is ~350', () {
      expect(StoryLength.short.targetWordCount, closeTo(350, 50));
    });
    test('long targetWordCount is ~800', () {
      expect(StoryLength.long.targetWordCount, closeTo(800, 100));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/models/story_options_test.dart
```

Expected: FAIL (file not found / compilation error).

- [ ] **Step 3: Create `app/lib/models/story_options.dart`**

```dart
enum StoryHero {
  knight, wizard, astronaut, pirate, fairy, dragon, robot, lion, bunny, superhero;

  String get displayName => switch (this) {
        StoryHero.knight => 'Knight / Princess',
        StoryHero.wizard => 'Wizard',
        StoryHero.astronaut => 'Astronaut',
        StoryHero.pirate => 'Pirate',
        StoryHero.fairy => 'Fairy',
        StoryHero.dragon => 'Dragon',
        StoryHero.robot => 'Robot',
        StoryHero.lion => 'Lion Cub',
        StoryHero.bunny => 'Bunny',
        StoryHero.superhero => 'Superhero',
      };

  String get emoji => switch (this) {
        StoryHero.knight => '🧝',
        StoryHero.wizard => '🧙',
        StoryHero.astronaut => '👨‍🚀',
        StoryHero.pirate => '🏴‍☠️',
        StoryHero.fairy => '🧚',
        StoryHero.dragon => '🐉',
        StoryHero.robot => '🤖',
        StoryHero.lion => '🦁',
        StoryHero.bunny => '🐰',
        StoryHero.superhero => '🦸',
      };

  String get promptName => switch (this) {
        StoryHero.knight => 'brave knight or princess',
        StoryHero.wizard => 'wise wizard',
        StoryHero.astronaut => 'adventurous astronaut',
        StoryHero.pirate => 'friendly pirate',
        StoryHero.fairy => 'magical fairy',
        StoryHero.dragon => 'friendly dragon',
        StoryHero.robot => 'curious robot',
        StoryHero.lion => 'brave lion cub',
        StoryHero.bunny => 'curious bunny',
        StoryHero.superhero => 'kind superhero',
      };
}

enum StoryTheme {
  adventure, bedtime, friendship, magic, space, ocean, forest, funny, birthday, kindness;

  String get displayName => switch (this) {
        StoryTheme.adventure => 'Adventure / Quest',
        StoryTheme.bedtime => 'Bedtime / Sleepy',
        StoryTheme.friendship => 'Friendship',
        StoryTheme.magic => 'Magic & Spells',
        StoryTheme.space => 'Space',
        StoryTheme.ocean => 'Ocean / Underwater',
        StoryTheme.forest => 'Enchanted Forest',
        StoryTheme.funny => 'Funny / Silly',
        StoryTheme.birthday => 'Birthday Surprise',
        StoryTheme.kindness => 'Kindness / Helping',
      };

  String get emoji => switch (this) {
        StoryTheme.adventure => '⚔️',
        StoryTheme.bedtime => '🌙',
        StoryTheme.friendship => '🤝',
        StoryTheme.magic => '✨',
        StoryTheme.space => '🚀',
        StoryTheme.ocean => '🌊',
        StoryTheme.forest => '🌲',
        StoryTheme.funny => '😂',
        StoryTheme.birthday => '🎂',
        StoryTheme.kindness => '💛',
      };

  String get promptName => switch (this) {
        StoryTheme.adventure => 'exciting adventure and quest',
        StoryTheme.bedtime => 'calm bedtime story with a peaceful, sleepy ending',
        StoryTheme.friendship => 'making a new friend and working together',
        StoryTheme.magic => 'magical world full of spells and enchantments',
        StoryTheme.space => 'space exploration with planets and stars',
        StoryTheme.ocean => 'underwater ocean adventure with sea creatures',
        StoryTheme.forest => 'enchanted forest with talking animals',
        StoryTheme.funny => 'funny and silly adventure full of laughs',
        StoryTheme.birthday => 'birthday party surprise and celebration',
        StoryTheme.kindness => 'act of kindness and helping others',
      };

  String get color => switch (this) {
        StoryTheme.adventure => '#7c2d12',
        StoryTheme.bedtime => '#1e1b4b',
        StoryTheme.friendship => '#831843',
        StoryTheme.magic => '#4a1d96',
        StoryTheme.space => '#0f172a',
        StoryTheme.ocean => '#0c4a6e',
        StoryTheme.forest => '#14532d',
        StoryTheme.funny => '#713f12',
        StoryTheme.birthday => '#9d174d',
        StoryTheme.kindness => '#854d0e',
      };
}

enum StoryLanguage {
  en, he, es;

  String get displayName => switch (this) {
        StoryLanguage.en => 'English',
        StoryLanguage.he => 'עברית',
        StoryLanguage.es => 'Español',
      };

  String get flag => switch (this) {
        StoryLanguage.en => '🇺🇸',
        StoryLanguage.he => '🇮🇱',
        StoryLanguage.es => '🇪🇸',
      };

  String get promptLabel => switch (this) {
        StoryLanguage.en => 'English',
        StoryLanguage.he => 'Hebrew',
        StoryLanguage.es => 'Spanish',
      };
}

enum StoryLength {
  short, long;

  String get displayName => switch (this) {
        StoryLength.short => 'Short',
        StoryLength.long => 'Long',
      };

  int get targetWordCount => switch (this) {
        StoryLength.short => 350,
        StoryLength.long => 800,
      };
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd app && flutter test test/models/story_options_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/models/story_options.dart test/models/story_options_test.dart && git commit -m "feat: add StoryOptions model (hero, theme, language, length enums)"
```

---

## Task 3: Create ElevenLabsService

**Files:**
- Create: `app/lib/services/elevenlabs_service.dart`
- Create: `app/test/services/elevenlabs_service_test.dart`

See spec at `docs/superpowers/specs/2026-04-21-ai-stories-design.md` for voice IDs per language.

Key implementation notes:
- One hardcoded voice per language (en: Matilda `XrExE9yKIg1WjnnlVkGX`, he: Adam `pNInz6obpgDQGcFmaJgB`, es: Charlotte `XB0fDUnXU5powFXDhCwa`)
- Model: `eleven_multilingual_v2`
- Injectable `http.Client` for testability
- `close()` method to release the client
- 60-second timeout on the POST

- [ ] **Step 1: Write the failing tests**
- [ ] **Step 2: Run to verify they fail**
- [ ] **Step 3: Implement ElevenLabsService**
- [ ] **Step 4: Run tests — confirm pass**
- [ ] **Step 5: Commit**

---

## Task 4: Create StoryService

**Files:**
- Create: `app/lib/services/story_service.dart`
- Create: `app/test/services/story_service_test.dart`

Pipeline: `generate(hero, theme, language, length)` → Claude API → ElevenLabs → temp file → `LibraryImportService.importAudioToLibrary()` → `autoAssignSprite(title)` → `AudioCard`.

Key notes:
- Model: `claude-haiku-4-5-20251001`, `max_tokens: 4096`
- `buildPrompt` and `parseClaudeResponse` are static (pure, testable)
- `parseClaudeResponse` handles both raw JSON and markdown-fenced responses
- `close()` method that closes `_httpClient` and `_tts`
- 60-second timeout on POST

- [ ] **Step 1: Write the failing tests**
- [ ] **Step 2: Run to verify they fail**
- [ ] **Step 3: Implement StoryService**
- [ ] **Step 4: Run tests — confirm pass**
- [ ] **Step 5: Commit**

---

## Task 5: Create ParentGenerateStoryScreen

**Files:**
- Create: `app/lib/ui/parent_generate_story_screen.dart`

4 states driven by `_step`: 0=hero, 1=theme, 2=language+length+generate, 3=loading.

Key notes:
- `PopScope(canPop: _step != 3)` blocks system back during generation
- `AnimatedSwitcher` + `KeyedSubtree(key: ValueKey(_step))` for transitions
- `_storyService` held as `late final`, initialized in `initState()`, closed in `dispose()`
- Cancel button on loading step via `_cancel()` + `_cancelled` flag
- On error: step returns to 2, error message shown, Generate button acts as Retry
- On success: `cardsProvider.notifier.addCard(card)` → `AnalyticsService.logCardCreated(method: 'ai_story')` → `context.pop()`
- Orphaned audio cleanup if `addCard` throws

- [ ] **Step 1: Implement ParentGenerateStoryScreen**
- [ ] **Step 2: Run analyze**
- [ ] **Step 3: Commit**

---

## Task 6: Wire router and add entry point button

**Files:**
- Modify: `app/lib/router.dart`
- Modify: `app/lib/ui/parent_list_screen.dart`

- [ ] **Step 1: Add route to router.dart** — `GoRoute(path: 'generate-story', builder: ... => const ParentGenerateStoryScreen())` inside `/parent`'s routes
- [ ] **Step 2: Add Generate Story button to `_LibraryHeader`** — new `onGenerateStory` callback, `_LibraryActionButton` with `Icons.auto_awesome_outlined`
- [ ] **Step 3: Pass callback from ParentListScreen** — `onGenerateStory: () => context.push('/parent/generate-story')`
- [ ] **Step 4: Verify compile** — `flutter analyze`
- [ ] **Step 5: Commit**

---

## Task 7: End-to-end verification

- [ ] **Step 1: Run the app** — `cd app && flutter run`
- [ ] **Step 2: Navigate to parent area** — tap settings gear, enter PIN `1234`, confirm Generate Story button appears
- [ ] **Step 3: Complete a full story generation** — pick Knight + Bedtime + English + Short → tap Generate → confirm status messages → card appears in library with title, sprite, dark color
- [ ] **Step 4: Play the generated story** — return to KidHomeScreen, tap card, confirm audio plays
- [ ] **Step 5: Test Hebrew generation** — repeat with Hebrew language, confirm Hebrew title and audio
- [ ] **Step 6: Test error recovery** — set invalid API key, attempt generate, confirm error message + Retry; restore key, confirm generation works
- [ ] **Step 7: Final commit**
