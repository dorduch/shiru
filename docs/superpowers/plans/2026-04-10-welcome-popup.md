# Welcome Popup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-time welcome popup with a personal note from the maker plus a feature preview, re-accessible from the About screen.

**Architecture:** A single dialog widget (`WelcomeDialog`) shown via `showDialog`, gated by a `WelcomePreferencesService` that wraps `SharedPreferences` for the `welcome_seen` flag. `KidHomeScreen` triggers it on first launch via a post-frame callback; `AboutScreen` re-opens it from a new tappable row. The dialog widget itself does not write to preferences — only the first-launch caller does, so re-opens from About don't change state.

**Tech Stack:** Flutter, Riverpod, `shared_preferences`, existing project theme (`AppColors`, `AppTypography`, `AppResponsive`).

---

## Spec Reference

- Spec: `docs/superpowers/specs/2026-04-10-welcome-popup-design.md`
- Read it before starting if you're unfamiliar with the feature.

---

## File Structure

**New files:**
- `app/lib/services/welcome_preferences_service.dart` — singleton wrapper around `SharedPreferences` for the `welcome_seen` flag.
- `app/lib/ui/widgets/welcome_dialog.dart` — `WelcomeDialog` stateless widget plus `showWelcomeDialog` helper.
- `app/test/services/welcome_preferences_service_test.dart` — unit tests for the service.
- `app/test/ui/widgets/welcome_dialog_test.dart` — widget tests for the dialog.

**Modified files:**
- `app/pubspec.yaml` — add `shared_preferences` dependency.
- `app/lib/ui/kid_home_screen.dart` — add post-frame callback in `_KidHomeScreenState.initState` that shows the dialog if not seen.
- `app/lib/ui/about_screen.dart` — add a "Welcome note" tappable row between hero and "Why Shiru exists".
- `app/test/ui/about_screen_test.dart` — assert the new row exists and tapping it opens the dialog.

---

## Task 1: Add `shared_preferences` dependency

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Add the dependency**

Open `app/pubspec.yaml`. Find the `dependencies:` block and add `shared_preferences` alphabetically. The block currently ends with `firebase_crashlytics: ^5.1.0`. Add this line in the right alphabetical position (between `record:` and `share_plus:`):

```yaml
  shared_preferences: ^2.3.2
```

If `pub get` later complains the version is unavailable, run `flutter pub add shared_preferences` from the `app/` directory and use whatever version it picks.

- [ ] **Step 2: Install the dependency**

Run from the `app/` directory:

```bash
cd app && flutter pub get
```

Expected: `Got dependencies!` (or similar success message). No error about `shared_preferences`.

- [ ] **Step 3: Verify analyze still passes**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "chore: add shared_preferences dependency for welcome flag"
```

---

## Task 2: Create `WelcomePreferencesService` with failing test

**Files:**
- Create: `app/test/services/welcome_preferences_service_test.dart`
- Create: `app/lib/services/welcome_preferences_service.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/services/welcome_preferences_service_test.dart` with this exact content:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiru/services/welcome_preferences_service.dart';

void main() {
  group('WelcomePreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      WelcomePreferencesService.resetForTesting();
    });

    test('hasSeenWelcome returns false when no value is set', () async {
      final service = WelcomePreferencesService.instance;
      expect(await service.hasSeenWelcome(), isFalse);
    });

    test('hasSeenWelcome returns true after markWelcomeSeen', () async {
      final service = WelcomePreferencesService.instance;
      await service.markWelcomeSeen();
      expect(await service.hasSeenWelcome(), isTrue);
    });

    test('markWelcomeSeen persists across new service reads', () async {
      await WelcomePreferencesService.instance.markWelcomeSeen();
      WelcomePreferencesService.resetForTesting();
      expect(
        await WelcomePreferencesService.instance.hasSeenWelcome(),
        isTrue,
      );
    });

    test('hasSeenWelcome returns false when SharedPreferences throws', () async {
      // Simulate failure by injecting a broken store via the testing seam.
      WelcomePreferencesService.resetForTesting();
      WelcomePreferencesService.debugSetPrefsLoader(() async {
        throw Exception('boom');
      });
      expect(
        await WelcomePreferencesService.instance.hasSeenWelcome(),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd app && flutter test test/services/welcome_preferences_service_test.dart
```

Expected: FAIL with errors like "Target of URI doesn't exist: 'package:shiru/services/welcome_preferences_service.dart'".

- [ ] **Step 3: Create the service**

Create `app/lib/services/welcome_preferences_service.dart` with this exact content:

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps SharedPreferences for the one-shot "welcome popup seen" flag.
///
/// Centralizing the key string here prevents typo drift across callers.
class WelcomePreferencesService {
  WelcomePreferencesService._();

  static const String _welcomeSeenKey = 'welcome_seen';

  static WelcomePreferencesService _instance = WelcomePreferencesService._();
  static WelcomePreferencesService get instance => _instance;

  static Future<SharedPreferences> Function() _prefsLoader =
      SharedPreferences.getInstance;

  /// Returns true if the welcome popup has already been shown and dismissed.
  ///
  /// Returns false on any error (fail-open: better to re-show than to silently
  /// hide). Errors are reported via `debugPrint` so Crashlytics' Flutter error
  /// handler can pick them up in release builds.
  Future<bool> hasSeenWelcome() async {
    try {
      final prefs = await _prefsLoader();
      return prefs.getBool(_welcomeSeenKey) ?? false;
    } catch (error, stack) {
      debugPrint('WelcomePreferencesService.hasSeenWelcome failed: $error');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }

  /// Marks the welcome popup as seen. Silently swallows errors — failing to
  /// persist the flag just means the popup will appear again next launch,
  /// which is the better failure mode than crashing.
  Future<void> markWelcomeSeen() async {
    try {
      final prefs = await _prefsLoader();
      await prefs.setBool(_welcomeSeenKey, true);
    } catch (error, stack) {
      debugPrint('WelcomePreferencesService.markWelcomeSeen failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  // ─── Test seams ─────────────────────────────────────────────────────────

  @visibleForTesting
  static void resetForTesting() {
    _instance = WelcomePreferencesService._();
    _prefsLoader = SharedPreferences.getInstance;
  }

  @visibleForTesting
  static void debugSetPrefsLoader(Future<SharedPreferences> Function() loader) {
    _prefsLoader = loader;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd app && flutter test test/services/welcome_preferences_service_test.dart
```

Expected: All 4 tests pass. `+4: All tests passed!`

- [ ] **Step 5: Run analyze**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/services/welcome_preferences_service.dart app/test/services/welcome_preferences_service_test.dart
git commit -m "feat: add WelcomePreferencesService for first-run flag"
```

---

## Task 3: Create `WelcomeDialog` widget with failing tests

**Files:**
- Create: `app/test/ui/widgets/welcome_dialog_test.dart`
- Create: `app/lib/ui/widgets/welcome_dialog.dart`

- [ ] **Step 1: Write the failing widget tests**

Create `app/test/ui/widgets/welcome_dialog_test.dart` with this exact content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/ui/widgets/welcome_dialog.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  required bool dismissible,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showWelcomeDialog(
                context,
                dismissible: dismissible,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('WelcomeDialog', () {
    testWidgets('shows heading, personal note, feature chips, and CTA', (
      tester,
    ) async {
      await _openDialog(tester, dismissible: true);

      expect(find.text('Welcome to Shiru'), findsOneWidget);
      expect(
        find.textContaining('I built this for my own kid'),
        findsOneWidget,
      );
      expect(find.text('Record stories from family'), findsOneWidget);
      expect(find.text('Import songs & audiobooks'), findsOneWidget);
      expect(find.text('Kids play independently'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Get Started button dismisses the dialog', (tester) async {
      await _openDialog(tester, dismissible: true);

      expect(find.byType(WelcomeDialog), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeDialog), findsNothing);
    });

    testWidgets('barrier tap dismisses when dismissible is true', (
      tester,
    ) async {
      await _openDialog(tester, dismissible: true);
      expect(find.byType(WelcomeDialog), findsOneWidget);

      // Tap near the top-left corner, well outside the centered card.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeDialog), findsNothing);
    });

    testWidgets('barrier tap does NOT dismiss when dismissible is false', (
      tester,
    ) async {
      await _openDialog(tester, dismissible: false);
      expect(find.byType(WelcomeDialog), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeDialog), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd app && flutter test test/ui/widgets/welcome_dialog_test.dart
```

Expected: FAIL with "Target of URI doesn't exist: 'package:shiru/ui/widgets/welcome_dialog.dart'".

- [ ] **Step 3: Create the widget**

Create `app/lib/ui/widgets/welcome_dialog.dart` with this exact content:

```dart
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Shows the welcome popup as a modal dialog.
///
/// When [dismissible] is false (first launch), the user can only close the
/// dialog by tapping the "Get Started" button. Both barrier taps and the
/// system back gesture are blocked.
Future<void> showWelcomeDialog(
  BuildContext context, {
  bool dismissible = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: Colors.black54,
    builder: (context) => PopScope(
      canPop: dismissible,
      child: const WelcomeDialog(),
    ),
  );
}

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  static const String personalNote =
      'I built this for my own kid — a player he controls himself, '
      'with no ads and no unsupervised content. Just stories from grandparents, '
      'favorite songs, and familiar voices.';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Shiru',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineMedium.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    personalNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _FeatureChip(
                    emoji: '🎙️',
                    label: 'Record stories from family',
                    background: Color(0xFFF0FDF4),
                  ),
                  const SizedBox(height: 12),
                  const _FeatureChip(
                    emoji: '🎵',
                    label: 'Import songs & audiobooks',
                    background: Color(0xFFEFF6FF),
                  ),
                  const SizedBox(height: 12),
                  const _FeatureChip(
                    emoji: '👧',
                    label: 'Kids play independently',
                    background: Color(0xFFFFF7ED),
                  ),
                  const SizedBox(height: 24),
                  _GetStartedButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color background;

  const _FeatureChip({
    required this.emoji,
    required this.label,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GetStartedButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Get Started',
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: AppColors.primaryShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'Get Started',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd app && flutter test test/ui/widgets/welcome_dialog_test.dart
```

Expected: All 4 tests pass. `+4: All tests passed!`

- [ ] **Step 5: Run analyze**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/widgets/welcome_dialog.dart app/test/ui/widgets/welcome_dialog_test.dart
git commit -m "feat: add WelcomeDialog widget with personal note and feature chips"
```

---

## Task 4: Show the dialog from `KidHomeScreen` on first launch

**Files:**
- Modify: `app/lib/ui/kid_home_screen.dart`

- [ ] **Step 1: Add imports**

Open `app/lib/ui/kid_home_screen.dart`. The current imports list ends with:

```dart
import 'pixel_sprite.dart';
```

Add these two lines immediately after it:

```dart
import 'widgets/welcome_dialog.dart';
import '../services/welcome_preferences_service.dart';
```

- [ ] **Step 2: Convert `_KidHomeScreenState` to use `initState`**

The current state class starts at line 26 and looks like:

```dart
class _KidHomeScreenState extends ConsumerState<KidHomeScreen> {
  String? _selectedCategoryId; // null means "All"

  @override
  Widget build(BuildContext context) {
```

Replace those lines with:

```dart
class _KidHomeScreenState extends ConsumerState<KidHomeScreen> {
  String? _selectedCategoryId; // null means "All"
  bool _welcomeChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWelcomeDialog();
    });
  }

  Future<void> _maybeShowWelcomeDialog() async {
    if (_welcomeChecked) return;
    _welcomeChecked = true;

    final service = WelcomePreferencesService.instance;
    final hasSeen = await service.hasSeenWelcome();
    if (hasSeen) return;
    if (!mounted) return;

    await showWelcomeDialog(context, dismissible: false);
    await service.markWelcomeSeen();
  }

  @override
  Widget build(BuildContext context) {
```

- [ ] **Step 3: Run analyze**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Run the existing test suite to make sure nothing broke**

```bash
cd app && flutter test
```

Expected: All existing tests still pass. There may be a new failure in `parent_list_screen_test.dart` or other widget tests if they navigate through `KidHomeScreen` — if so, those tests need their own `SharedPreferences.setMockInitialValues({'welcome_seen': true})` setup. **Add it only if a test fails**, like this in the test's `setUp`:

```dart
SharedPreferences.setMockInitialValues({'welcome_seen': true});
WelcomePreferencesService.resetForTesting();
```

(With imports `package:shared_preferences/shared_preferences.dart` and `package:shiru/services/welcome_preferences_service.dart`.)

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/kid_home_screen.dart
git commit -m "feat: show welcome dialog on first launch from KidHomeScreen"
```

If you also had to fix sibling tests in step 4, include those test files in the same commit.

---

## Task 5: Add "Welcome note" row to `AboutScreen`

**Files:**
- Modify: `app/lib/ui/about_screen.dart`
- Modify: `app/test/ui/about_screen_test.dart`

- [ ] **Step 1: Update the existing about screen test to assert the new row**

Open `app/test/ui/about_screen_test.dart`. After the existing assertions about `'About Shiru'` and `'Why Shiru exists'`, but before the `scrollUntilVisible('Private by default'...)` call, add these assertions:

Find this block (around line 30-36):

```dart
    expect(find.text('About Shiru'), findsOneWidget);
    expect(find.text('Why Shiru exists'), findsOneWidget);
    expect(
      find.textContaining('without turning listening time into a content feed'),
      findsOneWidget,
    );
```

Replace it with:

```dart
    expect(find.text('About Shiru'), findsOneWidget);
    expect(find.text('Welcome note'), findsOneWidget);
    expect(find.text('Why Shiru exists'), findsOneWidget);
    expect(
      find.textContaining('without turning listening time into a content feed'),
      findsOneWidget,
    );

    // Tapping the welcome note row opens the dialog.
    await tester.tap(find.text('Welcome note'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Shiru'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Dismiss it before continuing the rest of the test.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd app && flutter test test/ui/about_screen_test.dart
```

Expected: FAIL with something like "Expected: exactly one matching candidate / Actual: _TextFinder:<zero widgets with text 'Welcome note'>".

- [ ] **Step 3: Add the welcome note row to AboutScreen**

Open `app/lib/ui/about_screen.dart`. Add this import after the existing imports:

```dart
import 'widgets/welcome_dialog.dart';
```

Then find this block in the `ListView` (around lines 40-48):

```dart
                  children: const [
                    _AboutHero(),
                    SizedBox(height: 20),
                    _AboutSection(
                      title: 'Why Shiru exists',
                      body:
                          'Shiru exists to keep kids close to familiar voices without turning listening time into a content feed. It is for the small rituals that matter: a parent\'s goodnight message, a grandparent\'s story, a favorite song from home, or a voice note a child wants to hear again tomorrow.',
                    ),
```

The `_WelcomeNoteRow` widget you'll add at the bottom of the file has a `const` constructor, so it can stay inside the existing `const` list. Just insert two new entries between `_AboutHero()` and the first `_AboutSection`:

```dart
                  children: const [
                    _AboutHero(),
                    SizedBox(height: 20),
                    _WelcomeNoteRow(),
                    SizedBox(height: 16),
                    _AboutSection(
                      title: 'Why Shiru exists',
                      body:
                          'Shiru exists to keep kids close to familiar voices without turning listening time into a content feed. It is for the small rituals that matter: a parent\'s goodnight message, a grandparent\'s story, a favorite song from home, or a voice note a child wants to hear again tomorrow.',
                    ),
```

The rest of the list stays exactly as it was.

Then add the new `_WelcomeNoteRow` widget at the bottom of the file, after `_AboutFooter`:

```dart
class _WelcomeNoteRow extends StatelessWidget {
  const _WelcomeNoteRow();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => showWelcomeDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.waving_hand_rounded,
                  color: AppColors.primaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome note',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Re-read the note from the maker.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd app && flutter test test/ui/about_screen_test.dart
```

Expected: All tests pass. `+1: All tests passed!`

- [ ] **Step 5: Run analyze**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`. If you get warnings about `withValues` being unavailable, replace `AppColors.primary.withValues(alpha: 0.12)` with `AppColors.primary.withOpacity(0.12)` instead.

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/about_screen.dart app/test/ui/about_screen_test.dart
git commit -m "feat: add 'Welcome note' row to About screen"
```

---

## Task 6: Full test sweep + manual verification

**Files:** None (verification only)

- [ ] **Step 1: Run the entire test suite**

```bash
cd app && flutter test
```

Expected: All tests pass.

If any sibling widget test fails because it now tries to render `KidHomeScreen` and the dialog appears unexpectedly, fix it by adding to that test's `setUp`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiru/services/welcome_preferences_service.dart';

setUp(() {
  SharedPreferences.setMockInitialValues({'welcome_seen': true});
  WelcomePreferencesService.resetForTesting();
});
```

Commit any such fixes:

```bash
git add app/test/...
git commit -m "test: pre-mark welcome flag in tests that render KidHomeScreen"
```

- [ ] **Step 2: Run analyze on the whole app**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Manual smoke test on a device or simulator**

If you have a device or simulator handy:

```bash
cd app && flutter run
```

Then:

1. **First launch:** Confirm the welcome popup appears over the kid home screen, the personal note is readable, all three feature chips show, and the "Get Started" button is the only way to dismiss it (try tapping outside — it should not close).
2. **Second launch:** Hot-restart (`R` in the terminal). Confirm the popup does NOT appear.
3. **About re-access:** Tap the lock icon → enter PIN `1234` → tap "About" → tap "Welcome note". Confirm the dialog re-opens and is dismissible by tapping outside.
4. **Reinstall:** Uninstall the app (`flutter clean` then `flutter run`, or uninstall via the device). Confirm the popup re-appears on the next install.

If any of these fails, debug and fix before proceeding.

- [ ] **Step 4: Final commit (if any fixes from manual testing)**

```bash
git add -A
git commit -m "fix: address welcome popup manual-test findings"
```

Skip this step if no fixes were needed.

---

## Self-Review Notes

The plan covers every section of the spec:

- **First-launch behavior** → Task 4 (post-frame callback in `_KidHomeScreenState.initState`)
- **Reinstall** → naturally handled by `SharedPreferences` (no code needed); verified in Task 6 step 3
- **Re-access from About** → Task 5 (`_WelcomeNoteRow` widget)
- **Edge cases (force-kill, fail-open on prefs error)** → Task 2 (try/catch in service, test for failure path)
- **Non-dismissible on first launch** → Task 3 (`PopScope` + `barrierDismissible: false`)
- **Visual design** → Task 3 (full widget implementation)
- **Architecture (new files, modified files)** → Tasks 1–5
- **Testing (widget + service tests)** → Tasks 2 and 3

Out-of-scope items from the spec (broader onboarding, localization, analytics, animations, sprite art) are not addressed by any task — correct.
