# First-Time Welcome Popup — Design Spec
**Date:** 2026-04-10
**App:** Shiru (Flutter, local-first kids audio player)
**Status:** Ready for implementation planning

---

## Goal

Show a short, personal welcome message to parents the first time they open Shiru. The popup explains *why* the app exists (in the maker's own voice) and previews what they can do with it. It must feel intimate and human, not like a feature tour or growth funnel.

This is intentionally smaller in scope than the broader onboarding spec from 2026-03-29 (which has not been implemented). The welcome popup is a single dialog — no multi-screen flow, no PIN setup, no permission prompts. It is a personal note from the maker.

---

## User Stories

- As a first-time parent user, I want to understand who built this app and why, so the app feels human and trustworthy before I start setting it up.
- As a parent, I want to know what I can do with the app in a single glance, so I know whether it fits my needs.
- As a returning parent, I do not want to see the welcome popup again on every launch.
- As a curious parent, I want to be able to re-read the welcome note later if I want to remember what it said.

---

## Behavior

### First launch
- The dialog appears as a modal over `KidHomeScreen` once the first frame has rendered.
- On first launch, the dialog is non-dismissible by tapping outside the card and non-dismissible by the system back gesture (wrapped in `PopScope` with `canPop: false`). The only way out is the "Get Started" button.
- Tapping "Get Started" dismisses the dialog and sets a `welcome_seen` flag to `true` in `SharedPreferences`.
- The dialog never appears again on subsequent launches on the same install.

### Reinstall
- Because the flag lives in `SharedPreferences` (which is wiped on uninstall), reinstalling the app naturally re-shows the popup. No additional logic needed.

### Re-access from About
- The existing `AboutScreen` (`lib/ui/about_screen.dart`) gets a new tappable row labeled "Welcome note".
- Tapping it opens the same dialog widget. This re-display does not change the `welcome_seen` flag.

### Edge cases
- If the user force-kills the app before tapping "Get Started", the flag remains `false`, so the popup re-appears on the next launch. This is intentional — we want to ensure the user actually sees and acknowledges the welcome before it disappears forever.
- From the About screen, the dialog is dismissible by tapping outside or via back gesture. It does not change the `welcome_seen` flag.
- If `SharedPreferences` fails to load for any reason, the popup is shown (fail-open to the friendlier behavior). The error is logged to Crashlytics.

---

## Visual Design

The dialog is a centered white card floating over a semi-transparent dark overlay (`Colors.black54`).

**Card structure (top to bottom):**

1. **App icon** — `assets/images/app_icon.png`, 72×72px, rounded corners (radius 20), centered horizontally.
2. **Heading** — "Welcome to Shiru", 24px, weight 800, centered.
3. **Personal paragraph** — 15px, line-height 1.7, centered. The exact copy is:

   > I built this for my own kid — a player he controls himself, with no ads and no unsupervised content. Just stories from grandparents, favorite songs, and familiar voices.

4. **Feature chips** — three stacked rows, each with a colored pill background and an emoji icon on the left:
   - Green chip (`#F0FDF4`) — `🎙️` "Record stories from family"
   - Blue chip (`#EFF6FF`) — `🎵` "Import songs & audiobooks"
   - Orange chip (`#FFF7ED`) — `👧` "Kids play independently"

5. **Primary button** — full-width-ish "Get Started" pill button. Background `#22C55E` (the existing green from `KidHomeScreen` category tabs), white text, 14px vertical padding, radius 999.

**Card styling:**
- Background: white
- Border radius: 28px
- Padding: 32px
- Max width: 440px (so it doesn't get too wide on tablets)
- Shadow: matches existing dialog/card styling in the app

**Responsive behavior:**
- The card is wrapped in a scroll view so the content can scroll on very short screens (phones in landscape).
- On larger screens (tablets), the card stays centered and constrained to its max width.
- Uses existing `AppResponsive` helpers for spacing where appropriate.

---

## Architecture

### New files

**`app/lib/services/welcome_preferences_service.dart`**
- A thin wrapper around `SharedPreferences` for the `welcome_seen` flag.
- Methods: `Future<bool> hasSeenWelcome()` and `Future<void> markWelcomeSeen()`.
- Singleton-style access following the existing pattern (e.g., `AnalyticsService.instance`).
- Centralizing the key string in one file prevents typos elsewhere.

**`app/lib/ui/widgets/welcome_dialog.dart`**
- A `StatelessWidget` that builds the dialog's contents.
- A top-level helper function `Future<void> showWelcomeDialog(BuildContext context, {bool dismissible = true})` that calls `showDialog` with the right barrier behavior.
- The widget itself does not touch `SharedPreferences` — that is the caller's responsibility, so the same widget can be reused from `AboutScreen` without re-marking the flag.

### Modified files

**`app/lib/ui/kid_home_screen.dart`**
- Convert the existing `_KidHomeScreenState.initState` (or add it if not present in the relevant scope) to schedule a post-frame callback that:
  1. Reads `welcomePreferencesService.hasSeenWelcome()`.
  2. If `false`, calls `showWelcomeDialog(context, dismissible: false)`.
  3. Awaits the dialog, then calls `markWelcomeSeen()`.
- The check happens once per `_KidHomeScreenState` lifecycle (not on every rebuild). Use a `bool _welcomeChecked` guard.

**`app/lib/ui/about_screen.dart`**
- Add a new tappable row (matching the visual style of the existing `_AboutSection` cards) labeled "Welcome note" with a short subtitle like "Re-read the note from the maker".
- Tapping it calls `showWelcomeDialog(context)` (with default `dismissible: true`).
- The row should sit between the hero and the "Why Shiru exists" section, so it is the first interactive thing in the About list.

**`app/pubspec.yaml`**
- Add `shared_preferences: ^2.3.0` to dependencies. (Pin to whatever the current latest stable is at implementation time.)

---

## Data Flow

```
First launch
  └─ KidHomeScreen.initState
       └─ post-frame callback
            └─ WelcomePreferencesService.hasSeenWelcome() → false
                 └─ showWelcomeDialog(context, dismissible: false)
                      └─ user taps "Get Started"
                           └─ Navigator.pop
                                └─ WelcomePreferencesService.markWelcomeSeen()

Subsequent launches
  └─ KidHomeScreen.initState
       └─ post-frame callback
            └─ WelcomePreferencesService.hasSeenWelcome() → true
                 └─ no-op

Re-access from About
  └─ AboutScreen "Welcome note" row tap
       └─ showWelcomeDialog(context, dismissible: true)
            └─ user dismisses (button or barrier tap)
                 └─ no flag changes
```

---

## Testing

### Widget tests
- `welcome_dialog_test.dart`
  - Renders the dialog and asserts the heading, personal paragraph, and all three feature chips are present.
  - Tapping "Get Started" pops the dialog.
  - When `dismissible: false`, tapping the barrier does not dismiss.
  - When `dismissible: true`, tapping the barrier dismisses.

### Service tests
- `welcome_preferences_service_test.dart`
  - Uses `SharedPreferences.setMockInitialValues({})`.
  - `hasSeenWelcome()` returns `false` when no value is set.
  - `markWelcomeSeen()` then `hasSeenWelcome()` returns `true`.

### Integration / manual
- Fresh install → popup appears, dismiss → popup gone next launch.
- About screen → "Welcome note" row → popup re-appears, dismiss → flag still indicates seen.

---

## Out of Scope

- The broader multi-screen onboarding flow described in `2026-03-29-onboarding-design.md` (PIN setup, privacy promise screens, setup-path picker). That spec remains valid as a separate future effort.
- Localization. The popup ships in English only, matching the rest of the app today.
- Analytics. We will not log popup-shown / popup-dismissed events for v1. If we want to know whether parents read it, that can be added later.
- Animations beyond Flutter's default dialog enter/exit. No custom transitions.
- The feature chip emojis being swapped for `PixelSprite` art. Emojis are intentional for v1 to keep the implementation small and the popup visually distinct from the kid grid.

---

## Success Criteria

- A first-time parent sees the welcome popup before interacting with the app.
- The maker's personal "why" is the first thing a parent reads.
- The popup never appears twice on the same install (unless re-opened from About).
- A parent can find and re-read the welcome note from the About screen.
- Reinstalling the app re-shows the popup automatically (no extra code).
