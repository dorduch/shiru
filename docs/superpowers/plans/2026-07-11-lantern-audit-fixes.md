# Lantern Audit Fixes — post-rollout cleanup

**Context:** A post-rollout audit found 3 real, live-route-reachable regressions in batches already marked "done." All 7 batches + Foundation are otherwise verified complete (see `docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md`).

**Out of scope (flagged to the user, not acted on here):** `StoryWizardScreen`/`StoryReviewScreen` (dead, unreachable — deletion deferred, user's call), `FamilyVoicesTeaserScreen` (orphaned, unwired, has its own latent `StSectionHeader` bug but isn't reachable), the 5 "v1" screens (`KidHomeScreen`, `ParentCategoriesScreen`, `ParentCategoryEditScreen`, `ParentEditScreen`, `ParentListScreen` — substantial unreachable CRUD code, deletion needs explicit user confirmation), `/dev/gallery`'s missing production guard (spawned as a separate unrelated task).

---

## Fix 1: `StorytimePrivacyScreen`'s diagnostics toggle

**File:** `app/lib/ui/storytime_screens.dart` (`StorytimePrivacyScreen`, migrated in Batch 1 — only this class's toggle needs touching).

`StToggle` (`app/lib/ui/widgets/storytime/st_toggle.dart`) reads `StorytimeTokens.line2` for its "off" track — a pale warm-tan color, constant across day/bedtime, never overridden. Build `LanternToggle` (mirroring `StToggle`'s shape/API exactly, token source only changes — `line2`→`hush`, "on" color→`lantern`, check `StToggle`'s exact current implementation for the full field list), export from the `lantern` barrel, add a gallery entry, swap `StorytimePrivacyScreen`'s one call site.

## Fix 2: Systemic `StButton` (ember variant) palette mismatch — 9 call sites, 3 files

**Root cause:** `StButton`'s default `ember` variant sources its gradient from `StorytimeTokens.ctaGradient` (`[#E08A5B → #C9685A]`, muted terracotta) — a constant, never mode-aware, so it never picks up the new Lantern accent. `GlowButton` sources from `LanternTokens.ctaGradient` (`[#FFB566 → #E8834A]`, bright amber). Both variants are legible on dark (which is why earlier batches correctly called them "safe" per spec §5 item 4) but they render visibly different hues — the exact "doesn't look related" problem the whole rollout exists to fix, now reproduced within already-migrated screens. Later batches (5, 6) already made this exact swap for consistency (`StoryGeneratingScreen`'s "Try again", `AgeGateScreen`'s "Continue") — this fix brings the earlier batches in line with that same judgment call.

Swap every listed `StButton` (default ember variant, no other variant override) to `GlowButton`, same label/onTap, no behavior change:

**File: `app/lib/ui/storytime_screens.dart`** (one task — same file as Fix 1, do both together):
- `StorytimeAuthScreen` — "Continue"
- `ChildSetupScreen` — "Done"
- `StoryLibraryScreen` — "Try again" (×2, parent-mode and kid-mode error branches)

**File: `app/lib/ui/family_voices_screens.dart`** (one task — same file as Fix 3, do both together):
- `FamilyVoicesScreen`'s `_EmptyVoices` — "Add a voice"
- `VoiceConsentScreen` — "Continue"
- `GuidedCaptureScreen` — "Retry upload" (or equivalent — confirm exact current label)

**File: `app/lib/ui/add_audio_screens.dart`** (one task):
- `AddAudioCaptureScreen` — "Next"
- `AddAudioDetailsScreen` — "Replace audio" / "Save"

**Note:** `GlowButton.onTap` is non-nullable-by-default-usage but does support `null` (fixed in Batch 5) for a disabled state — check each call site for a busy/disabled pattern (e.g. `onTap: _busy ? null : ...`) and preserve it exactly; don't silently drop a disable guard during the widget swap.

## Fix 3: `GuidedCaptureScreen`'s recording-UI widgets — old palette family

**File:** `app/lib/ui/widgets/storytime/st_voice_capture.dart` (defines `StPrompt`, `StVoiceWave`, `StRecordButton` — confirmed via audit to have exactly one live consumer, `GuidedCaptureScreen`, plus the dev-only gallery which is unaffected either way since it wraps itself in its own theme).

These were purpose-built cream-on-dark for this one screen and hardcode `StorytimeTokens.night3`/`.cream`/`.ember`/`.gold` internally — a different hue family from `LanternTokens` (`nightCard` cool purple vs `night3` warm rose; `lantern` bright amber vs `ember`/`gold` terracotta/warm-gold). Migrate all three widgets' internals to `LanternTokens` (`night3`→`nightCard`, `cream`→`moon`, `ember`→`lantern`, `gold`→`lantern` or a distinct hue if two different accents were meaningfully distinguishing states — check the current usage before collapsing both to the same color). Also migrate `StDots`' one remaining `tokens.ember` read on this same screen if it's still present (confirm current state — `StDots` was noted as "reuse-as-is, not color-coupled" in the original spec, but that assumed default tokens; if it reads `ember` specifically, that needs `lantern` too).

Do this in the same task as Fix 2's `family_voices_screens.dart` work (same coherent screen, same file family).

## Verification (all tasks)

- `flutter analyze` clean (baseline: 11 pre-existing infos).
- Full `flutter test` — compare against the 142 passed / 5 failed baseline (post-Batch-7).
- Visual spot-check via `/dev/gallery`'s existing showcase sections for `LanternToggle` and the migrated voice-capture widgets, or simulator if convenient.
