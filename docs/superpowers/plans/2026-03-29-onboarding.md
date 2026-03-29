# Onboarding Experience Implementation Plan

**Goal:** Add a first-run onboarding flow that explains Shiru's local-first model, clearly calls out the optional voice cloud exception with deletion language, promises no ads to children, and moves parents into first-card setup quickly.

**Architecture:** Add a persisted onboarding-complete flag, a dedicated onboarding route stack for fresh installs, and reusable trust/disclosure copy blocks that also appear in parent settings and voice-specific screens. Reuse the current age gate, PIN gate, parent library, import, and voice flows where possible instead of creating parallel setup systems.

**Tech Stack:** Flutter, Riverpod, `flutter_secure_storage`, `go_router`

**Spec:** `docs/superpowers/specs/2026-03-29-onboarding-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `app/lib/providers/onboarding_provider.dart` | Persist onboarding completion and maybe track current first-run state |
| Modify | `app/lib/router.dart` | Route fresh installs through onboarding before `/` |
| Create | `app/lib/ui/onboarding/onboarding_welcome_screen.dart` | Shared welcome screen |
| Create | `app/lib/ui/onboarding/onboarding_trust_screen.dart` | Privacy, voice exception, and no-ads promise |
| Create | `app/lib/ui/onboarding/onboarding_parent_setup_screen.dart` | First-run hand-off into age gate + PIN creation |
| Create | `app/lib/ui/onboarding/onboarding_setup_choice_screen.dart` | First task choice: one card, bulk import, or explore |
| Modify | `app/lib/providers/pin_provider.dart` | Support explicit first-run PIN creation instead of silent default PIN |
| Modify | `app/lib/ui/age_gate_screen.dart` | Adjust copy for first-run parent setup context |
| Modify | `app/lib/ui/pin_gate_screen.dart` | Support create/set PIN mode and first-run wording |
| Modify | `app/lib/ui/parent_list_screen.dart` | Add a lightweight persistent trust section or empty-state trust footer |
| Modify | `app/lib/ui/voice_record_screen.dart` | Tighten detailed disclosure copy so it matches onboarding promises |
| Modify | `app/lib/ui/story_builder_screen.dart` | Align provider-step disclosure with onboarding wording |

---

## Task 1: Persist First-Run Onboarding State

**Files:**
- Create: `app/lib/providers/onboarding_provider.dart`

- Add secure-storage backed state:
  - `hasCompletedOnboarding`
  - optional `hasSeenTrustScreen` only if needed for partial resume
- Keep it intentionally small. A single completion flag is enough for MVP.

Implementation notes:
- Mirror the existing `pinProvider` pattern.
- Do not store onboarding state in SQLite; this is app-level state, not content data.

Acceptance:
- Fresh install returns `false`
- Completed onboarding returns `true` across app relaunches

---

## Task 2: Add a First-Run Route Stack

**Files:**
- Modify: `app/lib/router.dart`
- Create: onboarding screens under `app/lib/ui/onboarding/`

- Add an onboarding entry path such as `/onboarding/welcome`.
- If onboarding is incomplete, initial app launch should land in onboarding instead of kid home.
- Once onboarding is complete, the initial route returns to `/`.

Recommended route sequence:
1. `/onboarding/welcome`
2. `/onboarding/trust`
3. `/onboarding/parent-setup`
4. `/onboarding/setup-choice`

Implementation notes:
- Keep these screens outside the adult gate logic; they are the setup path.
- After completion, use the existing parent and kid routes instead of duplicating flows.

Acceptance:
- Returning users do not see onboarding again.
- Fresh installs always see onboarding before home.

---

## Task 3: Build the Trust Screen Carefully

**Files:**
- Create: `app/lib/ui/onboarding/onboarding_trust_screen.dart`

This is the key screen. It should include three promise cards:

1. `Everything stays on this device by default`
2. `Optional family voices may use cloud generation`
3. `We will never show ads to your children`

Required copy constraints:
- State clearly that stories, library data, recordings, categories, and playback are on-device by default.
- State clearly that family voice generation is the exception.
- State clearly that temporary cloud voices created for that process are deleted afterward.
- Avoid claiming that every provider creates a stored cloud voice.

Acceptance:
- The trust screen stands on its own without additional explanation.
- The voice wording matches real behavior in `StoryBuilderService`.

---

## Task 4: Replace Silent Default PIN With First-Run PIN Creation

**Files:**
- Modify: `app/lib/providers/pin_provider.dart`
- Modify: `app/lib/ui/pin_gate_screen.dart`
- Optional create: `app/lib/ui/onboarding/onboarding_parent_setup_screen.dart`

Current issue:
- The app silently creates a default PIN of `1234`, which weakens the onboarding trust story.

Recommended change:
- Store no PIN until first-run setup.
- In onboarding, ask the parent to create a 4-digit PIN.
- After that, use the existing PIN gate for returning sessions.

Fallback if scope must stay smaller:
- Keep the existing PIN provider structure, but force the first-run user through a `ChangePin`-style creation step before library access.

Acceptance:
- No production first-run path leaves the parent on a default `1234` PIN.

---

## Task 5: Keep Voice Consent Detailed at Point of Use

**Files:**
- Modify: `app/lib/ui/voice_record_screen.dart`
- Modify: `app/lib/ui/story_builder_screen.dart`

Align the detailed disclosure copy with the onboarding trust promise.

Recommended detailed copy:

> Family voice narration is optional. When you use it, your recording and story request may be sent to OpenAI and our voice providers to generate narration. If a temporary cloud voice is created for that process, it is deleted afterward. Use only your own adult voice or a voice you have permission to use.

Implementation notes:
- Keep the consent checkbox in the voice recording flow.
- Do not push this longer disclosure into the general onboarding screens.

Acceptance:
- Voice-specific wording is legally safer and product-consistent.
- Messaging no longer conflicts across onboarding and generation flows.

---

## Task 6: Add A Persistent Trust Surface In Parent Space

**Files:**
- Modify: `app/lib/ui/parent_list_screen.dart`

Add a compact trust section that parents can revisit later.

Recommended placement:
- Empty library state footer, or
- A compact card near the top of the parent library screen, or
- Overflow menu item leading to a future privacy/info sheet

Required bullets:
- `On-device by default`
- `Family voices may use cloud generation`
- `Temporary cloud voices are deleted after use`
- `No ads shown to children`

Acceptance:
- Parents can revisit the trust claims after onboarding without hunting.

---

## Task 7: Keep The Setup Choice Focused On First Playback

**Files:**
- Create: `app/lib/ui/onboarding/onboarding_setup_choice_screen.dart`

Offer three actions:
- `Add One Story`
- `Import A Bunch`
- `Explore First`

Routing:
- `Add One Story` → `/parent/edit`
- `Import A Bunch` → `/parent/bulk-import`
- `Explore First` → `/`

Implementation notes:
- Keep Story Builder and premium/family-voice upsell out of this screen.
- The onboarding success path is "first card plays," not "discover every advanced feature."

Acceptance:
- Parent can complete the first-run path without seeing premium friction.

---

## Task 8: QA The Trust Claims Against Real Behavior

**Files:**
- Review only

Before shipping, verify that the copy is still true:

- Library data remains local
- Voice sample handling still matches `StoryBuilderService`
- ElevenLabs temporary voices are deleted in the `finally` block
- Cartesia flow still uses inline clip mode
- No kid-mode screens contain ad or promo placements

If implementation changes later, update onboarding copy before release.

---

## Open Questions

- Should onboarding be skippable on fresh install if there are zero cards?
  - Recommendation: no. It is the right place to establish trust and create a secure parent path.
- Should the trust screen include provider names?
  - Recommendation: no on the main onboarding path, yes in the detailed voice disclosure.
- Should no-ads messaging mention subscriptions?
  - Recommendation: no. The promise should stay about the child experience, not monetization mechanics.

---

## Verification

1. Fresh install launches into onboarding.
2. Trust screen shows local-first, voice exception, and no-ads messaging.
3. Parent completes age check and creates a non-default PIN.
4. Parent can choose a quick setup path and reach first playback.
5. Relaunch skips onboarding.
6. Voice recording and story generation screens use disclosure copy that matches the onboarding promise.
