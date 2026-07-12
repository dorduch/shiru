# UX Review Fixes — Implementation Plan (2026-07-12)

Source: five-track app-wide UX review (kid flows, parent/onboarding, story creation/content,
voice-invite web flow, live simulator walkthrough). This plan sequences the fixes into six
phases ordered by user harm: data-loss/lockout traps first, then the invite flow's fragile
edges, quota economics, visible polish, pre-reader/delight, and hygiene. Each task lists
files, approach, and acceptance criteria. Sizing: S (<½ day), M (½–1 day), L (1–2 days).

Verification baseline for every phase: `flutter analyze` clean, targeted tests pass
(note: 9 pre-existing test failures on clean checkout are known and not regressions),
plus a simulator walkthrough of the touched flow. Parent PIN on the test sim: 1111.
Story generation fails on the sim (App Check disabled) — verify generation-path changes
via unit tests + the functions emulator.

---

## Phase 1 — Ship-blockers: data loss & lockouts

### 1.1 Stop the silent destructive migration (L)
**Files:** `app/lib/services/storytime_migration_service.dart`, `app/lib/main.dart:72`,
new one-time migration screen in `app/lib/ui/`.
**Problem:** `runIfNeeded()` wipes the legacy Shiru card table and deletes all media files
at boot, before any UI, with no consent.
**Approach (preferred):** import instead of delete. Legacy cards are local audio files +
titles — map them into the current `AudioCard` schema as "Added by you" library items and
keep the media files in place. Anything unmappable (video cards, since there is no video
path today) gets moved to an `archive/` subfolder in Documents, not deleted.
**Fallback (if import proves >2 days):** block the migration behind an explicit full-screen
choice — "Keep my recordings" (archive to folder, skip wipe) vs "Start fresh" — with copy
that names what will be deleted.
**Accept:** upgrading a device with legacy Shiru data never deletes a media file without an
explicit, informed user action. Fresh installs are unaffected. Migration runs exactly once.

### 1.2 PIN recovery ("Forgot PIN") (M)
**Files:** `app/lib/ui/pin_gate_screen.dart`, `app/lib/providers/pin_provider.dart`,
`app/lib/services/auth_repository.dart`.
**Approach:** add a "Forgot PIN?" link on the PIN gate → re-authenticate with the Firebase
account (email/password re-auth, or Apple/Google `reauthenticateWithProvider`) → on success,
clear stored PIN and route into PIN creation. The account credential, not the PIN, is the
root of trust — this is independent of local lockout state.
**Also:** fresh-install detection for iOS. Keychain (`first_unlock_this_device`) survives
reinstall; store an install marker file in Documents (wiped on uninstall). At boot, if the
marker is missing but a PIN exists in secure storage, clear PIN + age-gate flag so a
reinstall behaves like a reinstall.
**Accept:** a locked-out parent with account credentials can always reset the PIN; reinstall
on iOS no longer resurrects a forgotten PIN. Rate-limit (5 tries/30s) unchanged.

### 1.3 Fix the expired-audio resume trap (S/M)
**Files:** `app/lib/ui/storytime_screens.dart` (`_onJob` ~:719, `_import` ~:751),
`app/lib/services/active_story_job_service.dart`.
**Approach:**
- Guard `_import()`: if `job.downloadUrl` is null/empty on a `ready` job, treat as
  *expired*, clear the active-job marker, and show a friendly dead-end with "Make it again"
  (routes to composer with the same draft) instead of the retry loop.
- Clear the active-job marker in the `catch` of `_import` when the failure is non-retryable
  (missing URL), keep it for transient network failures.
**Accept:** relaunch >24h after a completed-but-unimported job lands on a friendly screen
once, marker cleared; no infinite loop. Add a widget/unit test for the null-URL path.

### 1.4 Invite page: survive tab reloads (M)
**Files:** `public/invite/app.js` (`main()` :532–561, redeem flow).
**Approach:** persist `{token, redeemed: true}` plus the Firebase custom-token session in
`sessionStorage` keyed by invite token. On load: if a live Firebase Auth session with
`invite:true` claims exists for this token (or the stored custom token still signs in),
skip `redeemVoiceInviteFn` entirely and restore UI state (which prompts are already
uploaded — server upload is already idempotent per-prompt). Only ever call redeem once per
browser session. No backend change required; the 2-hour `assertActiveInviteSession` window
still bounds everything.
**Accept:** backgrounding/reloading mid-recording resumes the flow within the 2h window;
a genuinely reused/expired link still shows the terminal error.

### 1.5 Run the ElevenLabs webm smoke test (S, do before 1.4 ships)
**Files:** `functions/dev/real_clone_demo.mjs` (exists, never run).
**Approach:** execute against the real ElevenLabs API with a Chrome-recorded
`audio/webm` sample and a Safari `audio/mp4` sample. Record results in
`docs/superpowers/specs/2026-07-11-voice-invite-implementation-plan.md`.
If webm fails: either transcode server-side in `processVoiceClone` (ffmpeg layer) or force
`MediaRecorder` to a known-good mimeType via `isTypeSupported` probing (see 5.6).
**Accept:** a documented pass/fail for both containers; if fail, a follow-up task is filed
and the invite page is not sent to real relatives until resolved.

### 1.6 Real informed consent on the invite page (M + legal checkpoint)
**Files:** `public/invite/index.html`, `public/invite/app.js` (:205 render, :222 consent),
`functions/src/index.ts` (`createVoiceInvite` — add inviter/child display fields),
`app/lib/ui/family_voices_screens.dart` (invite creation passes the names).
**Approach:**
- Carry `invitedBy` (parent display name) and app name in the invite doc; render
  "**[Parent]** invited you to record your voice for bedtime stories in **Storytime**"
  instead of greeting grandma with her own name.
- Replace the bare checkbox with a short informed-consent block: this creates an AI-generated
  copy of your voice; used only to narrate stories for this family; you can ask [parent] to
  delete it anytime; recordings and the voice are removed on deletion.
- Checkpoint: legal/privacy review sign-off before sending to real relatives (was explicitly
  deferred in the spec).
**Accept:** the page names the inviter, explains cloning in plain language, and states
retention/deletion. Consent stored server-side unchanged (timestamped).

---

## Phase 2 — Quota visibility & duplicate-job guard

### 2.1 Make the daily quota visible (M)
**Files:** `app/lib/ui/storytime_screens.dart` (home), `app/lib/ui/story_composer_screen.dart`,
`app/lib/providers/storytime_providers.dart`, `app/lib/services/story_generation_repository.dart`.
**Approach:** the server already returns `remaining` on `createStoryJob`; additionally read
`users/{uid}/generationUsage/{utcDay}` + `storytimeConfig/generation.dailyQuota` via a
Firestore provider so the count is correct before the first job of the day. Show a small,
kid-neutral indicator ("3 stories left today", moon-dot meter) on the composer, always, and
on Home when remaining ≤ 3. Copy stays in-voice — no "quota".
**Accept:** parent and child can see remaining stories before composing; hitting zero is
never a surprise. Firestore rules already permit user-scoped reads (verify; adjust if not).

### 2.2 Prevent duplicate in-flight jobs (S/M)
**Files:** `app/lib/ui/storytime_screens.dart` (`_start` :668), `app/lib/ui/story_composer_screen.dart` (:301).
**Approach:** in `_start()`, when `existingJobId` is null, consult
`activeStoryJobService.load(uid)` first — if a live job exists, subscribe to it instead of
minting a new one (mirrors the cold-start resume path). Composer CTA unchanged.
Add an explicit "Back home" control to the generating screen's non-error state (the router
comment at `router.dart:44` promises one; it doesn't exist).
**Accept:** Android hardware-back → re-tap CTA re-attaches to the running job; only one
quota unit spent per intent. Unit test the guard.

### 2.3 Minimum loading-state duration on generate (S)
**Files:** `app/lib/ui/storytime_screens.dart` (generating screen).
**Approach:** hold the "Writing your story…" state ≥1s before swapping to an error so an
instant server rejection doesn't feel like a broken button.
**Accept:** instant failures still show friendly error, after a visible beat.

---

## Phase 3 — Visible polish pass (all caught live on the simulator)

One batch, one teammate, one PR. All S-sized.

| # | Fix | Files |
|---|-----|-------|
| 3.1 | "Add your own audio" section headers use night-surface tokens (`moon`/`moonDim`) — currently near-invisible | `app/lib/ui/add_audio_screens.dart` |
| 3.2 | Reskin `AudioRecorderWidget` to Lantern tokens (kill hardcoded cream/mint hexes) and fix the "Shiru" mic-permission string → "Storytime" | `app/lib/ui/widgets/audio_recorder_widget.dart` (:81, :339, :652, :784) |
| 3.3 | Composer slot shuffle-glyph overlaps last letter of label ("HER⟳O") — add spacing in slot header row | composer slot widget under `app/lib/ui/widgets/storytime/` |
| 3.4 | Narrator cards: allow 2-line name/tagline or shorten; give locked family-voice card a visible teaser ("Add a family voice") instead of a floating lock | `app/lib/ui/story_composer_screen.dart` |
| 3.5 | Account screen: show real email / provider names; never render "Unknown" | `app/lib/ui/storytime_screens.dart` (account section ~:1676) |
| 3.6 | Library tiles: 2-line titles; badge only non-default origins ("Made by you"), drop the repeated "Ready-made" | `app/lib/ui/storytime_screens.dart` (~:989–1140) |
| 3.7 | De-duplicate age-gate/PIN copy ("GROWN-UPS ONLY" + "Grown-ups only…"; "one more time" ×2) | `app/lib/ui/age_gate_screen.dart`, `pin_gate_screen.dart` |
| 3.8 | Player art tint: hue-preserving overlay so the yellow fox card doesn't go muddy brown | player art panel widget |
| 3.9 | Redraw "Builder" concept icon (reads as food cloche, not hard hat) | `app/lib/ui/concept_icons.dart` |

**Accept:** re-run the simulator walkthrough on Home → composer → library → player →
parent screens; screenshots show none of the above.

---

## Phase 4 — Pre-reader accessibility & delight

### 4.1 Speak the Home screen and slot questions (M)
**Files:** `app/lib/ui/storytime_screens.dart` (home :524–577), `app/lib/ui/story_slot_sheet.dart` (:79–84),
`app/lib/services/audio_label_service.dart`.
**Approach:** reuse the existing composer TTS pattern. Speak greeting once on Home entry
(debounced, not on every rebuild); speak tile labels on long-press or first-tap; speak the
slot-sheet question ("Who is our hero?") when the sheet opens.
**Accept:** a non-reader can navigate Home and understand each composer prompt by ear.

### 4.2 Bigger story text + size control (S/M)
**Files:** `app/lib/theme/app_typography.dart` (:126), player screen.
**Approach:** raise `storyBody` default to ~20px/1.8; add an A/A⁺ toggle on the player
(persisted per device).
**Accept:** read-along comfortable at arm's length; comfort-band autoscroll still correct
at both sizes.

### 4.3 Story-end celebration (S)
**Files:** `app/lib/ui/storytime_screens.dart` (StoryEndScreen :1468).
**Approach:** one restrained reward beat — gentle star/firefly particle drift + soft chime +
light haptic on entry. Respect reduced-motion. Keep it calm (bedtime), not confetti-cannon.
**Accept:** finishing a story visibly/audibly acknowledges the moment.

### 4.4 Animate the mascot while narrating (S)
**Files:** `app/lib/ui/widgets/storytime/story_avatar.dart` (:54–59).
**Approach:** pass `SpriteState.active` when the player is playing — the animation already
exists in `PixelSprite`, it's just never wired.
**Accept:** mascot pulses during playback, idles on pause.

### 4.5 Player accessibility labels (S)
**Files:** `app/lib/ui/widgets/storytime/st_scene_player.dart` (:306–359).
**Approach:** Semantics labels for play/pause (stateful), back, and the seek slider; also
add slack between the slider and the play button or enlarge slider hit-test padding so small
fingers don't scrub accidentally.
**Accept:** VoiceOver announces all player controls; play/pause reachable without grazing
the slider.

### 4.6 Bedtime dimming (M — product call, default ON at night)
**Files:** player screen; new dependency (`screen_brightness`).
**Approach:** on the player/story-end (night surfaces), ease screen brightness down ~30%
after 10s of no interaction; restore on touch/navigation. Parent toggle under settings.
**Accept:** night listening doesn't blast full brightness; system brightness restored on exit.

---

## Phase 5 — Invite-flow hardening (post-blockers)

| # | Task | Size | Files / notes |
|---|------|------|---------------|
| 5.1 | Parent push notification on voice `ready`/`failed` (FCM) — today status only updates while the Family Voices screen is open | M/L | `functions/src/index.ts` (`processVoiceClone`), app FCM setup |
| 5.2 | Invite status on `VoiceInviteShareScreen`: pending / opened / submitted / expired, live | M | `family_voices_screens.dart` :554–706, invite doc statuses already exist |
| 5.3 | Recording timer + soft auto-stop (~45s/prompt) + `recorder.onerror`/track-`ended` recovery | S/M | `public/invite/app.js` :327–388 |
| 5.4 | `MediaRecorder.isTypeSupported` probing; pass explicit mimeType; fail fast to upload path | S | `public/invite/app.js` :348, informed by 1.5 results |
| 5.5 | Upload fallback: add `capture` attr + plain instructions ("Open Voice Memos, record, then choose it here") | S | `public/invite/index.html`, app.js :271–285 |
| 5.6 | Require the invite path (subject's own consent) for non-household voices, or add equivalent consent copy to the in-app record/upload paths — product+legal decision | M | `family_voices_screens.dart` :328–365 |

---

## Phase 6 — Hygiene & guardrails

| # | Task | Size | Notes |
|---|------|------|-------|
| 6.1 | Delete dead UI: `kid_home_screen.dart`, `video_playback_screen.dart`, `about_screen.dart`, `widgets/welcome_dialog.dart`, `bulk_import_screen.dart` (+ their tests). The About/Welcome copy makes stale privacy claims ("No account required", "Audio never uploaded") — a trust incident if ever re-linked. Decide separately whether video returns; if not, drop `CardMediaType.video` handling from import validation | M | confirm unreferenced via grep before each delete |
| 6.2 | Gate `/dev/gallery` behind `!kReleaseMode` | S | `app/lib/router.dart` :126–130 |
| 6.3 | Remove orphaned `content/storytime/*.txt` (source of truth is `app/assets/storytime/starter_stories.json`); add a README pointer in `content/` | S | prevents editing the wrong files |
| 6.4 | Runtime guard for curated timing: word-count match between `.timing.json` and manifest `storyText`, else fall back to estimate (mirrors backend `deriveWordStarts` defensiveness) | S | `app/lib/services/curated_timing_service.dart` + test |
| 6.5 | Document the iOS-26 sim `objective_c` dylib crash + fix (`flutter clean` + Pods wipe) in `app/README.md`; try pinning/upgrading the package | S | every new teammate hits this |
| 6.6 | Update `CLAUDE.md` project overview — it still describes the pre-Storytime local-only pixel-art app (no backend, hardcoded PIN 1234); ~all of it is wrong now | S | prevents future agents working from a false map |

---

## Backlog (product decisions, not scheduled)

- **Multi-child profiles** — `ChildProfileService` is one-profile-per-uid; a two-kid family needs two accounts. Decide before the data model calcifies.
- **Guest / "try one story first" path** — account creation is required before any content; the starter-story seed softens but doesn't remove the wall.
- **Age-banded curated stories** — all six starters are ~350 words (early band) regardless of child age; add middle/older variants and cover space/castle/adventure registers.
- **Re-narration path** — plan §6 decision B promises re-narrating persisted story text on demand (also the proper fix behind 1.3's "Make it again").
- **Safety reviewer diversity** — generation and safety review both use `claude-haiku-4-5`; consider a different/stronger reviewer model or rules layer for highest-risk categories.
- **Rate limiting / abuse protection** on the unauthenticated invite endpoints (token entropy already strong; this is cost/DoS hygiene).
- **"WHAT HAPPENS" slot phrasing** — abstract for 3-year-olds; watch telemetry, consider concrete phrasings.

## Suggested execution order & sizing

- **Phase 1:** ~4–6 dev-days. 1.1 is the long pole; 1.3, 1.5 are quick — start them first. 1.4+1.5+1.6 unblock sending invites to real people.
- **Phase 2:** ~2 days. Do before any store release; pairs naturally with Phase 1 testing.
- **Phase 3:** ~1–1.5 days, single batch PR, verify with a fresh simulator walkthrough.
- **Phase 4:** ~3 days. 4.3/4.4/4.5 are quick wins; 4.1 is the highest-value item for the stated 3–5 audience.
- **Phases 5–6:** ~4 days combined, parallelizable with 3–4.

Dependencies: 1.5 → 5.4; 1.6 needs legal sign-off before real-relative sends; 6.1 video
decision gates whether import keeps validating video formats.
