# Parent audio upload/record + Listen redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a parent add a card from their own recorded/uploaded audio (with edit support for those cards), and redesign the child Listen page into a Home-style rich tile grid.

**Architecture:** Reuse the existing `AudioRecorderWidget` (record + file-pick, defaults wired to `RecordingService` + `LibraryImportService`) inside two new storytime-styled screens behind the parent gate. Cards persist via the existing `cardsProvider`/`AudioCard` with a new `StoryOrigin.uploaded` (TEXT column, no migration). The Listen kid view becomes a `GridView` of rich `PixelSprite` tiles mirroring `StorytimeHomeScreen`.

**Tech Stack:** Flutter, Riverpod, go_router, sqflite, flutter_svg, existing storytime design system (`StorytimeTokens`, `St*` widgets).

## Global Constraints

- Run all commands from `app/`. Lint: `flutter analyze` must pass clean. Tests: `flutter test`.
- Icons must be rich custom art, not Material glyphs: `PixelSprite` on tiles; hand-drawn `SvgPicture.string` for the add-audio glyph (per project memory: icon bg = tile bg).
- Copy in sentence case. Origin subtitles exactly: `curated`→"Ready-made", `uploaded`→"Your audio", `generated`→"Your story".
- Audio-only feature: build `AudioCard` with `mediaType: CardMediaType.audio`.
- No DB schema change — `story_origin` is `TEXT NOT NULL DEFAULT 'generated'`; the enum `.name` round-trips.
- `StoryLibraryScreen` is dual-use: redesign **only** `parentMode == false`; the `parentMode == true` (Manage stories) list keeps delete + gains an edit affordance on `uploaded` rows.

---

### Task 1: Model — `StoryOrigin.uploaded` + origin subtitle helper

**Files:**
- Modify: `lib/models/storytime_models.dart:184`
- Create: `lib/models/story_origin_label.dart`
- Test: `test/models/story_origin_label_test.dart`

**Interfaces:**
- Produces: `enum StoryOrigin { curated, generated, uploaded }`; `String storyOriginSubtitle(StoryOrigin origin)`; `String storyOriginSemantics(StoryOrigin origin)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/story_origin_label_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/models/story_origin_label.dart';

void main() {
  test('subtitle maps every origin', () {
    expect(storyOriginSubtitle(StoryOrigin.curated), 'Ready-made');
    expect(storyOriginSubtitle(StoryOrigin.uploaded), 'Your audio');
    expect(storyOriginSubtitle(StoryOrigin.generated), 'Your story');
  });

  test('semantics phrase maps every origin', () {
    expect(storyOriginSemantics(StoryOrigin.curated), 'ready-made story');
    expect(storyOriginSemantics(StoryOrigin.uploaded), 'your audio');
    expect(storyOriginSemantics(StoryOrigin.generated), 'your story');
  });
}
```

> Note: confirm the package name in `pubspec.yaml` (`name:`). If it is not `shiru`, replace `package:shiru/` in all imports throughout this plan.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/story_origin_label_test.dart`
Expected: FAIL — `story_origin_label.dart` not found / `uploaded` undefined.

- [ ] **Step 3: Add enum value**

In `lib/models/storytime_models.dart:184` change:
```dart
enum StoryOrigin { curated, generated, uploaded }
```

- [ ] **Step 4: Create the helper**

```dart
// lib/models/story_origin_label.dart
import 'storytime_models.dart';

/// Subtitle shown on a story tile/row for each origin.
String storyOriginSubtitle(StoryOrigin origin) {
  switch (origin) {
    case StoryOrigin.curated:
      return 'Ready-made';
    case StoryOrigin.uploaded:
      return 'Your audio';
    case StoryOrigin.generated:
      return 'Your story';
  }
}

/// Lower-case phrase used inside accessibility labels.
String storyOriginSemantics(StoryOrigin origin) {
  switch (origin) {
    case StoryOrigin.curated:
      return 'ready-made story';
    case StoryOrigin.uploaded:
      return 'your audio';
    case StoryOrigin.generated:
      return 'your story';
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/models/story_origin_label_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/models/storytime_models.dart lib/models/story_origin_label.dart test/models/story_origin_label_test.dart
git commit -m "feat(storytime): add StoryOrigin.uploaded + origin subtitle helper"
```

---

### Task 2: Rich add-audio SVG glyph

**Files:**
- Modify: `lib/ui/concept_icons.dart` (append after `headphonesIconSvg`, ~line 353)

**Interfaces:**
- Produces: `const String addAudioIconSvg` (48×48 viewBox, same palette family as `storybookIconSvg`).

- [ ] **Step 1: Append the constant**

```dart
/// Microphone glyph for the "Add your own audio" action. Same hand-drawn
/// style as [storybookIconSvg]/[headphonesIconSvg]; sits directly on the
/// tile/entry background (no token box behind it).
const String addAudioIconSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<rect x="19" y="8" width="10" height="20" rx="5" fill="#8B7CF6" stroke="#4E2E96" stroke-width="2.2"/>'
    '<path d="M14 22 a10 10 0 0 0 20 0" fill="none" stroke="#5B4FB0" stroke-width="2.6" stroke-linecap="round"/>'
    '<path d="M24 32 V38" stroke="#5B4FB0" stroke-width="2.6" stroke-linecap="round"/>'
    '<path d="M18 38 H30" stroke="#5B4FB0" stroke-width="2.6" stroke-linecap="round"/>'
    '<rect x="22" y="12" width="4" height="3" rx="1.5" fill="#C3B8F4"/>'
    '<path d="M38 9 l1.1 2.7 2.7 1.1 -2.7 1.1 -1.1 2.7 -1.1 -2.7 -2.7 -1.1 2.7 -1.1 Z" fill="#F2C84B" stroke="#C9881A" stroke-width="0.8" stroke-linejoin="round"/>'
    '</svg>';
```

- [ ] **Step 2: Verify it parses**

Run: `flutter analyze lib/ui/concept_icons.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/concept_icons.dart
git commit -m "feat(storytime): add rich mic glyph for add-audio action"
```

---

### Task 3: Add-audio draft provider + capture/details screens (create mode)

**Files:**
- Create: `lib/providers/add_audio_provider.dart`
- Create: `lib/ui/add_audio_screens.dart`
- Test: `test/ui/add_audio_screens_test.dart`

**Interfaces:**
- Consumes: `AudioRecorderWidget` (`lib/ui/widgets/audio_recorder_widget.dart`), `MediaSelection` (`lib/services/library_import_service.dart`), `cardsProvider` (`lib/providers/cards_provider.dart`), `autoAssignSprite` + `hexOrFallback` (`lib/models/sprites.dart`), `StTextField`/`StButton`/`StSectionHeader` (`lib/ui/widgets/storytime/storytime.dart`), `StorytimeTokens`, `addAudioIconSvg`.
- Produces:
  - `final addAudioDraftProvider = StateProvider<MediaSelection?>((ref) => null);`
  - `class AddAudioCaptureScreen extends ConsumerWidget` — record/pick UI; on selection sets `addAudioDraftProvider` and `context.go('/parent/add-audio/details')`.
  - `class AddAudioDetailsScreen extends ConsumerStatefulWidget { const AddAudioDetailsScreen({super.key, this.editingCardId}); final String? editingCardId; }` — title + color + preview; Save creates (or, Task 6, updates) the card.

- [ ] **Step 1: Create the draft provider**

```dart
// lib/providers/add_audio_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/library_import_service.dart';

/// Holds the captured/imported audio between the capture and details steps.
final addAudioDraftProvider = StateProvider<MediaSelection?>((ref) => null);
```

- [ ] **Step 2: Write the failing widget test (create flow)**

```dart
// test/ui/add_audio_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/providers/add_audio_provider.dart';
import 'package:shiru/providers/cards_provider.dart';
import 'package:shiru/services/library_import_service.dart';
import 'package:shiru/theme/app_theme.dart';
import 'package:shiru/ui/add_audio_screens.dart';

class _FakeCards extends CardsNotifier {
  final added = <AudioCard>[];
  @override
  Future<void> addCard(AudioCard card) async => added.add(card);
}

void main() {
  testWidgets('details Save builds an uploaded audio card', (tester) async {
    final cards = _FakeCards();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardsProvider.overrideWith((ref) => cards),
          addAudioDraftProvider.overrideWith(
            (ref) => const MediaSelection(
              path: '/tmp/a.m4a',
              mediaType: CardMediaType.audio,
              duration: Duration(seconds: 12),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AddAudioDetailsScreen(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Grandma tale');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(cards.added, hasLength(1));
    final card = cards.added.single;
    expect(card.title, 'Grandma tale');
    expect(card.storyOrigin, StoryOrigin.uploaded);
    expect(card.mediaType, CardMediaType.audio);
    expect(card.audioPath, '/tmp/a.m4a');
    expect(card.durationMs, 12000);
  });
}
```

> Check `CardsNotifier`'s exact class name + `cardsProvider` type in `lib/providers/cards_provider.dart` and adjust the fake/override to match (it is a `StateNotifierProvider`). If overriding the notifier is awkward, instead assert via an in-memory `DatabaseService` per existing provider tests in `test/providers/`.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/ui/add_audio_screens_test.dart`
Expected: FAIL — `add_audio_screens.dart` not found.

- [ ] **Step 4: Implement the screens**

```dart
// lib/ui/add_audio_screens.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_card.dart';
import '../models/sprites.dart';
import '../models/storytime_models.dart';
import '../providers/add_audio_provider.dart';
import '../providers/cards_provider.dart';
import '../services/library_import_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../ui/concept_icons.dart';
import '../ui/pixel_sprite.dart';
import 'widgets/storytime/storytime.dart';

/// Swatches offered for the card color (warm storytime palette).
const _swatches = <String>[
  'E6A487', 'F2C84B', '8B7CF6', '7FB5A6', 'E2885A', 'D98C9B', '6FA8D6', '9CC97B',
];

class AddAudioCaptureScreen extends ConsumerStatefulWidget {
  const AddAudioCaptureScreen({super.key, this.editingCardId});
  final String? editingCardId;

  @override
  ConsumerState<AddAudioCaptureScreen> createState() =>
      _AddAudioCaptureScreenState();
}

class _AddAudioCaptureScreenState extends ConsumerState<AddAudioCaptureScreen> {
  MediaSelection? _selection;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: tokens.cream,
        title: Text('Add your own audio',
            style: AppTypography.headlineSmall.copyWith(color: tokens.ink)),
        leading: BackButton(onPressed: () => context.go('/parent')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SvgPicture.string(addAudioIconSvg, width: 96, height: 96),
              const SizedBox(height: 12),
              const StSectionHeader(
                title: 'Record or upload',
                subtitle: 'Record a voice now, or pick an audio file.',
              ),
              const SizedBox(height: 16),
              AudioRecorderWidget(
                currentSelection: _selection,
                onMediaSelected: (sel) => setState(() => _selection = sel),
              ),
              const Spacer(),
              StButton(
                label: 'Next',
                onTap: _selection == null
                    ? null
                    : () {
                        ref.read(addAudioDraftProvider.notifier).state =
                            _selection;
                        final id = widget.editingCardId;
                        context.go(id == null
                            ? '/parent/add-audio/details'
                            : '/parent/edit-audio/$id');
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddAudioDetailsScreen extends ConsumerStatefulWidget {
  const AddAudioDetailsScreen({super.key, this.editingCardId});
  final String? editingCardId;

  @override
  ConsumerState<AddAudioDetailsScreen> createState() =>
      _AddAudioDetailsScreenState();
}

class _AddAudioDetailsScreenState extends ConsumerState<AddAudioDetailsScreen> {
  late final TextEditingController _title;
  String _color = _swatches.first;
  AudioCard? _editing; // set in Task 6 for edit mode

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _defaultTitle());
  }

  String _defaultTitle() {
    final sel = ref.read(addAudioDraftProvider);
    return sel?.sourceName?.trim().isNotEmpty == true
        ? sel!.sourceName!
        : 'My recording';
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final draft = ref.read(addAudioDraftProvider);
    if (draft == null) {
      context.go('/parent/add-audio');
      return;
    }
    final title = _title.text.trim().isEmpty ? 'My recording' : _title.text.trim();
    final cards = ref.read(cardsProvider.notifier);
    final existing = ref.read(cardsProvider).valueOrNull ?? const <AudioCard>[];
    final card = AudioCard(
      id: const Uuid().v4(),
      title: title,
      color: _color,
      audioPath: draft.path,
      mediaType: CardMediaType.audio,
      storyOrigin: StoryOrigin.uploaded,
      durationMs: draft.duration?.inMilliseconds ?? 0,
      position: existing.length,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await cards.addCard(card);
    ref.read(addAudioDraftProvider.notifier).state = null;
    if (mounted) context.go('/parent/stories');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: tokens.cream,
        title: Text('Card details',
            style: AppTypography.headlineSmall.copyWith(color: tokens.ink)),
        leading: BackButton(onPressed: () => context.go('/parent/add-audio')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: hexOrFallback(_color),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: PixelSprite(
                  sprite: autoAssignSprite(_title.text.trim().isEmpty
                      ? 'My recording'
                      : _title.text.trim()),
                  scale: 4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            StTextField(
              controller: _title,
              hintText: 'Card title',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Text('Color', style: AppTypography.labelLarge.copyWith(color: tokens.ink2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _swatches)
                  GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: hexOrFallback(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == hex ? tokens.ink : tokens.line,
                          width: _color == hex ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            StButton(label: 'Save', onTap: _save),
          ],
        ),
      ),
    );
  }
}
```

> Verify exact constructor params of `StTextField`, `StButton`, `StSectionHeader` in `lib/ui/widgets/storytime/` and adjust (`onTap` vs `onPressed`, `hintText` vs `hint`, `title`/`subtitle`). Verify `autoAssignSprite` + `hexOrFallback` signatures in `lib/models/sprites.dart`. Verify `AppTypography.labelLarge` exists (else use `bodyMedium`).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/ui/add_audio_screens_test.dart`
Expected: PASS. Then `flutter analyze` clean for the new files.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/add_audio_provider.dart lib/ui/add_audio_screens.dart test/ui/add_audio_screens_test.dart
git commit -m "feat(storytime): add-audio capture + details screens (create mode)"
```

---

### Task 4: Routes + dashboard entry

**Files:**
- Modify: `lib/router.dart` (under the `/parent` route's `routes:`)
- Modify: `lib/ui/storytime_screens.dart` (dashboard `StorytimeParentDashboard`, ~1759–1801)

**Interfaces:**
- Consumes: `AddAudioCaptureScreen`, `AddAudioDetailsScreen` (Task 3), `addAudioIconSvg`.

- [ ] **Step 1: Add routes**

In `lib/router.dart`, add to the `routes:` list of the `/parent` `GoRoute` (alongside `child`, `stories`, …):
```dart
GoRoute(
  path: 'add-audio',
  builder: (context, state) => const AddAudioCaptureScreen(),
  routes: [
    GoRoute(
      path: 'details',
      builder: (context, state) => const AddAudioDetailsScreen(),
    ),
  ],
),
GoRoute(
  path: 'edit-audio/:id',
  builder: (context, state) =>
      AddAudioDetailsScreen(editingCardId: state.pathParameters['id']),
),
```
Add `import 'ui/add_audio_screens.dart';` at the top.

- [ ] **Step 2: Add the dashboard entry**

In `StorytimeParentDashboard.build`, after the "Manage stories" `_DashboardEntry` (storytime_screens.dart ~1773), insert. Because `_DashboardEntry` takes an `IconData icon`, add a rich variant: give `_DashboardEntry` an optional `Widget? leading` and render it instead of the `CircleAvatar(Icon)` when provided. Then:
```dart
const SizedBox(height: 8),
_DashboardEntry(
  icon: Icons.add, // ignored when leading is provided
  leading: SvgPicture.string(addAudioIconSvg, width: 40, height: 40),
  title: 'Add your own audio',
  subtitle: 'Record a voice or upload a file',
  onTap: () => context.go('/parent/add-audio'),
),
```
Update `_DashboardEntry` (storytime_screens.dart:1808) to accept `this.leading` and in `build` use `leading ?? CircleAvatar(... Icon(icon) ...)`. Add `import 'package:flutter_svg/flutter_svg.dart';` and `import 'concept_icons.dart';` if not present.

- [ ] **Step 3: Verify navigation**

Run: `flutter analyze`
Expected: clean. Manual smoke (Task 7 covers full run): dashboard → "Add your own audio" pushes the capture screen.

- [ ] **Step 4: Commit**

```bash
git add lib/router.dart lib/ui/storytime_screens.dart
git commit -m "feat(storytime): wire add-audio routes + dashboard entry"
```

---

### Task 5: Listen kid view → rich tile grid

**Files:**
- Modify: `lib/ui/storytime_screens.dart` — `StoryLibraryScreen` (1276), `_StoryTile` (1328); reuse `_ResumeStrip` (652).
- Test: `test/ui/story_library_grid_test.dart`

**Interfaces:**
- Consumes: `storyOriginSubtitle`/`storyOriginSemantics` (Task 1), `PixelSprite`, `autoAssignSprite`, `hexOrFallback`, `_ResumeStrip`.
- Produces: `_StoryGridTile` (private); `StoryLibraryScreen` kid branch renders a `GridView`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/ui/story_library_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/providers/cards_provider.dart';
import 'package:shiru/theme/app_theme.dart';
import 'package:shiru/ui/storytime_screens.dart';

AudioCard _card(String id, String title, StoryOrigin origin) => AudioCard(
      id: id, title: title, color: 'E6A487', audioPath: '/x.m4a',
      storyOrigin: origin, position: 0, createdAt: 0,
    );

void main() {
  testWidgets('kid Listen shows a grid with origin subtitles', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        cardsProvider.overrideWith((ref) => _StubCards([
              _card('1', 'Fox', StoryOrigin.generated),
              _card('2', 'Gran', StoryOrigin.uploaded),
            ])),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const StoryLibraryScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Your story'), findsOneWidget);
    expect(find.text('Your audio'), findsOneWidget);
  });
}
```

> Implement `_StubCards` to match the real notifier type (a `StateNotifier<AsyncValue<List<AudioCard>>>` seeded with the list — mirror an existing test in `test/providers/` or `test/ui/parent_list_screen_test.dart`). Confirm `AppTheme.light` is the correct theme getter name.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/story_library_grid_test.dart`
Expected: FAIL — no `GridView` (currently a `ListView`).

- [ ] **Step 3: Rewrite the kid branch + add `_StoryGridTile`**

Replace the `Scaffold`/`body` of `StoryLibraryScreen.build` so that when `!parentMode` it renders the Home-style layout; keep the existing `AppBar`+`ListView` for `parentMode`. Kid branch:
```dart
// inside build, when !parentMode:
final resumable = (cards.valueOrNull ?? const <AudioCard>[])
    .where((c) => c.playbackPosition > 5000)
    .toList()
  ..sort((a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0));
return Scaffold(
  backgroundColor: tokens.cream,
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            BackButton(onPressed: () => context.go('/home')),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Listen', style: AppTypography.headlineMedium.copyWith(color: tokens.ink)),
                Text('${cards.valueOrNull?.length ?? 0} stories',
                    style: AppTypography.bodySmall.copyWith(color: tokens.ink2)),
              ],
            )),
          ]),
          if (resumable.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ResumeStrip(card: resumable.first),
          ],
          const SizedBox(height: 16),
          Expanded(child: cards.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: StButton(
              label: 'Try again', onTap: ref.read(cardsProvider.notifier).loadCards)),
            data: (stories) => stories.isEmpty
              ? Center(child: Text('No stories yet. Make one from Home.',
                  style: AppTypography.bodySmall.copyWith(color: tokens.ink2)))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: stories.length,
                  itemBuilder: (context, i) => _StoryGridTile(card: stories[i]),
                ),
          )),
        ],
      ),
    ),
  ),
);
```
Add `_StoryGridTile`:
```dart
class _StoryGridTile extends StatelessWidget {
  const _StoryGridTile({required this.card});
  final AudioCard card;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Semantics(
      button: true,
      label: '${card.title}, ${storyOriginSemantics(card.storyOrigin)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.go('/story/${card.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.line),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Expanded(child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: hexOrFallback(card.color),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: PixelSprite(
                sprite: card.spriteKey != null
                    ? (predefinedSprites[card.spriteKey!] ?? autoAssignSprite(card.title))
                    : autoAssignSprite(card.title),
                scale: 3,
              ),
            )),
            const SizedBox(height: 8),
            Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge.copyWith(
                    color: tokens.ink, fontWeight: FontWeight.w700)),
            Text(storyOriginSubtitle(card.storyOrigin),
                style: AppTypography.labelMedium.copyWith(color: tokens.ink2)),
          ]),
        ),
      ),
    );
  }
}
```
Also update the existing `_StoryTile` subtitle/semantics (lines 1336, 1340) to use the helpers so the parent list matches:
```dart
label: '${card.title}, ${storyOriginSemantics(card.storyOrigin)}',
// ...
subtitle: storyOriginSubtitle(card.storyOrigin),
```
Add `import '../models/story_origin_label.dart';`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/story_library_grid_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/storytime_screens.dart test/ui/story_library_grid_test.dart
git commit -m "feat(storytime): redesign kid Listen into rich tile grid"
```

---

### Task 6: Edit flow (uploaded cards only)

**Files:**
- Modify: `lib/ui/add_audio_screens.dart` (`AddAudioDetailsScreen` edit mode + Replace audio)
- Modify: `lib/ui/storytime_screens.dart` (`_StoryTile` edit affordance in parent mode)
- Test: extend `test/ui/add_audio_screens_test.dart`

**Interfaces:**
- Consumes: `cardsProvider.updateCard`, `LibraryImportService.deleteImportedMedia`, `AudioCard.copyWith`.

- [ ] **Step 1: Write the failing edit test**

```dart
// add to test/ui/add_audio_screens_test.dart
testWidgets('edit mode updates title/color via updateCard', (tester) async {
  final existing = AudioCard(
    id: 'c1', title: 'Old', color: 'E6A487', audioPath: '/old.m4a',
    storyOrigin: StoryOrigin.uploaded, durationMs: 5000, position: 0, createdAt: 1);
  final cards = _FakeCards()..seed([existing]); // _FakeCards exposes updated list + seed()
  await tester.pumpWidget(ProviderScope(
    overrides: [cardsProvider.overrideWith((ref) => cards)],
    child: MaterialApp(theme: AppTheme.light,
      home: const AddAudioDetailsScreen(editingCardId: 'c1')),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'New name');
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  expect(cards.updated.single.id, 'c1');
  expect(cards.updated.single.title, 'New name');
  expect(cards.updated.single.audioPath, '/old.m4a'); // unchanged when not replaced
});
```

> Extend `_FakeCards` with `updated`, `seed()`, and override `updateCard`/`build` state to expose the seeded card. Match real `CardsNotifier` API.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/add_audio_screens_test.dart`
Expected: FAIL — edit mode not implemented (no card loaded / Save calls addCard).

- [ ] **Step 3: Implement edit mode in `AddAudioDetailsScreen`**

In `initState`, when `widget.editingCardId != null`, load the card from `cardsProvider` and prefill `_title`, `_color`, `_editing`:
```dart
@override
void initState() {
  super.initState();
  final id = widget.editingCardId;
  if (id != null) {
    final list = ref.read(cardsProvider).valueOrNull ?? const <AudioCard>[];
    _editing = list.where((c) => c.id == id).cast<AudioCard?>().firstWhere(
        (c) => true, orElse: () => null);
  }
  _title = TextEditingController(text: _editing?.title ?? _defaultTitle());
  if (_editing != null) _color = _editing!.color;
}
```
Rewrite `_save` to branch:
```dart
Future<void> _save() async {
  final title = _title.text.trim().isEmpty ? 'My recording' : _title.text.trim();
  final cards = ref.read(cardsProvider.notifier);
  final replacement = ref.read(addAudioDraftProvider); // non-null only if audio replaced
  if (_editing != null) {
    final old = _editing!;
    final newPath = replacement?.path ?? old.audioPath;
    final updated = old.copyWith(
      title: title,
      color: _color,
      audioPath: newPath,
      durationMs: replacement?.duration?.inMilliseconds ?? old.durationMs,
      playbackPosition: replacement != null ? 0 : old.playbackPosition,
    );
    await cards.updateCard(updated);
    if (replacement != null && replacement.path != old.audioPath) {
      await LibraryImportService.deleteImportedMedia(old.audioPath);
    }
    ref.read(addAudioDraftProvider.notifier).state = null;
    if (mounted) context.go('/parent/stories');
    return;
  }
  // ... existing create path (build new AudioCard, addCard) ...
}
```
Add a "Replace audio" `StButton` (only when `_editing != null`) that does
`context.go('/parent/add-audio')` after stashing the editing id — simplest: route to capture with the id via `AddAudioCaptureScreen(editingCardId: _editing!.id)` (already supported in Task 3 Next handler, which routes to `/parent/edit-audio/$id`). Confirm `copyWith` accepts `audioPath`, `playbackPosition`, `durationMs` (audio_card.dart:108+); add params to `copyWith` if missing.

- [ ] **Step 4: Add edit affordance to parent list**

In `_StoryTile.build` (parent mode), when `card.storyOrigin == StoryOrigin.uploaded`, show an edit icon before delete (use a `Row` in `trailing`):
```dart
trailing: parentMode
  ? Row(mainAxisSize: MainAxisSize.min, children: [
      if (card.storyOrigin == StoryOrigin.uploaded)
        GestureDetector(
          onTap: () => context.go('/parent/edit-audio/${card.id}'),
          child: const Icon(Icons.edit_outlined, color: AppColors.ink3, size: 20)),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: () => _delete(context, ref),
        child: const Icon(Icons.delete_outline, color: AppColors.ink3, size: 20)),
    ])
  : const Icon(Icons.chevron_right_rounded, color: AppColors.ink3, size: 20),
```

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/ui/add_audio_screens_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/add_audio_screens.dart lib/ui/storytime_screens.dart lib/models/audio_card.dart test/ui/add_audio_screens_test.dart
git commit -m "feat(storytime): edit uploaded audio cards (title/color/replace audio)"
```

---

### Task 7: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze + full test suite**

Run: `flutter analyze && flutter test`
Expected: no issues; all tests pass.

- [ ] **Step 2: Manual smoke on device/emulator**

Run: `flutter run`. Verify:
1. Dashboard → "Add your own audio" → record a clip → Next → title+color → Save → lands on Manage stories with the new card.
2. Home → Listen shows a rich tile grid; the new card shows "Your audio"; tapping plays it.
3. Resume partway, return to Listen → resume strip appears.
4. Manage stories → edit icon present only on the uploaded card → change title/color → Save → reflected in Listen. Replace audio → new clip plays.
5. Upload-a-file path also produces a working card.

- [ ] **Step 3: Final commit (if any fixups)**

```bash
git add -A && git commit -m "chore(storytime): verification fixups for parent audio + Listen redesign"
```
