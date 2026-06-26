# Storytime MVP — Task Tracker

> Durable task list. Companion to [storytime-mvp-plan.md](storytime-mvp-plan.md). Update checkboxes as work progresses. Status legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked.

**Locked decisions (do not re-litigate):**
- Billing deferred → `$0` testing; Family features behind a free-on `entitlement` flag.
- Quota → 10 stories/day/user (`storytimeConfig/generation.dailyQuota`, server-tunable).
- `narratorKey` = built-in enum **or** ref to `users/{uid}/voices/{id}`; server resolves both.
- Persistence **B** → story text durable in Firestore; audio is a cache (device-primary, cloud-ephemeral).
- Design direction = attached Storytime wireframes + landing (re-skin off legacy Shiru).
- Backend foundation = existing `functions/` dir (from codex/v2); extend, don't rewrite.

**Current focus:** Branch `feature/storytime-mvp`, 5 commits (docs, M1 design, backend lift, Phase 1 baseline, Phase 2 screen rebuild). ✅ M1 design system. ✅ codex/v2 audited + backend lifted (must-fixes applied; tests 4/4 with `nvm use 22`). ✅ Phase 1 baseline (codex/v2 app lifted, design system preserved). ✅ Phase 2: ALL Storytime screens rebuilt on `St*` components, day/bedtime theme wired, legacy `storytime_theme.dart` deleted, portrait locked. `flutter analyze` 0 errors. iOS build needed `pod repo update` (new firebase pods) — done. ✅ Follow-along player + audio-path fix + parent-gate re-skin all DONE + verified on sim. Whole app now on the design system (no legacy-grey holdouts in the live flow). ▶ NEXT candidates: (1) verify onboarding flow signed-out; (2) child profile → Firestore; (3) content & safety settings (NEEDS product def — see M3); (4) re-narrate flow (needs backend path); then M4 Family voice tier (testing-only build OK; legal review §7 before public). Home TabBar + StParentGate swap were re-checked and are NOT needed (see M2/M3 notes). flutter at `$HOME/Downloads/flutter/bin`; iOS pods need `LANG=en_US.UTF-8`. ✅ **M4 Family voice tier implemented** (backend 8/8 tests + lint clean; 6 screens + picker, analyze 0 errors; `firebase_storage` pod added, app boots healthy on sim). ▶ M4 e2e clone loop is UNVERIFIED — blocked only on a `firebase deploy --only functions` + App Check sim token (user-gated: cost + prod). NEXT: deploy functions to verify clone e2e, OR M5 hardening / content-safety product def. NOTE: launched standalone debug builds via `simctl install` HANG on the launch storyboard — must use `flutter run` to attach the Dart VM.

---

## Milestone 0 — Foundations / decisions
- [x] Write MVP plan (APIs + design system) — `docs/storytime-mvp-plan.md`
- [x] Resolve §6 open questions (billing, quota, narrator, persistence)
- [x] Capture legal gates as launch-only (§7)
- [x] AUDIT codex/v2 — done (see "codex/v2 audit outcome" section below). codex/v2 = main + 1 commit; near-complete Storytime refactor. Verdict: lift backend/wiring, discard its theme+screens.
- [x] Decided: keep `main` as base, LIFT backend+wiring from codex/v2, rebuild screens on `St*` components. Working on branch `feature/storytime-mvp` (carries M1).
- [x] Lift backend from codex/v2: `functions/src/*.ts`, `functions/{package,tsconfig}`, `firestore.rules`, `storage.rules`, `firebase.json`, `firestore.indexes.json`. Build clean + domain tests 4/4 (needs `nvm use 22` — default shell node is v16, too old).
- [ ] Stand up Firebase project (Auth, Firestore, Storage, Functions, App Check) + confirm secrets exist: `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_WALLY|FERN|RAY` (rules/config now lifted)
- [ ] Seed `storytimeConfig/generation` doc (`dailyQuota: 10`) — code now defaults to 10 if missing

## Milestone 1 — Design system + component library (recommended first)
- [x] Define color tokens (day + bedtime modes) from wireframes — `app/lib/theme/app_colors.dart` (legacy names aliased)
- [x] Define typography (Fraunces display, Inter UI) + `storyBody` + `eyebrow` — `app/lib/theme/app_typography.dart` (google_fonts added)
- [x] Define spacing / radius / elevation scales — `app_radius.dart` (large→20, +sheet 36), `app_shadows.dart` (warm)
- [x] Build `StorytimeTheme` (`day`/`bedtime` ThemeData + `StorytimeTokens` ThemeExtension) — `app/lib/theme/app_theme.dart`; wired in `main.dart`. `flutter analyze` clean.
- [x] Component: `Button` (ember / dark / ghost / line / soft)
- [x] Component: `Input` / `Field`
- [x] Component: `ChoiceCard` (default/selected + pixel-art thumbnail)
- [x] Component: `Tile` (standard / big)
- [x] Component: `Row` (avatar + title + sub + trailing: lock / chevron / soon)
- [x] Component: `Eyebrow` + `Title` + `Sub` header trio
- [x] Component: `Dots` (wizard progress)
- [x] Component: `Seg` (segmented control)
- [x] Component: `Toggle` (switch)
- [x] Component: `Hint`, `Chip`, `Tonechip`, `Lock`, `TagSoon`
- [x] Component: `CaptureRing` + `Prompt` + `RecordButton` + `VoiceWave`
- [x] Component: `ScenePlayer` (art panel, follow-along text, transport, progress)
- [x] Component: `TabBar` (bottom nav)
- [x] Component: `ParentGate` (grown-ups-only entry)
- [x] Reuse `PixelSprite` / `SpriteDef` for wizard thumbnails
- [x] Gallery/widgetbook screen exercising every component in both modes

## Milestone 2 — Story generation path (free tier, production-grade)
### Backend
- [x] Persist full `story` text on the job doc in `processStoryJob` (decision B) — added `story: story.story`
- [x] Verified `cleanupExpiredStoryAudio` + `confirmStoryImported` clear ONLY audio fields (downloadUrl/storagePath) — `story`/`title` preserved
- [x] Confirmed `validateStoryRequest` enums match client `storytime_models.dart` exactly (audit)
### Client
- [x] Mirror domain enums on client — `storytime_models.dart` matches `domain.ts` exactly (lifted)
- [x] Route generation through `createStoryJob` + job stream — `story_generation_repository.dart` (lifted)
- [x] On-device Anthropic path removed — `story_service.dart`/`elevenlabs_service.dart` deleted (lifted)
- [x] Job-stream wiring — `StoryGeneratingScreen` watches job doc, maps all 6 states (lifted)
- [x] On ready: download → import to SQLite → `confirmStoryImported` (lifted)
- [x] Follow-along player text — DONE + VERIFIED on sim. `AudioCard.storyText` (SQLite v10), `StoryJob.story`, import saves `job.story`, starter stories carry text (from `content/storytime/*.txt`). Player shows text with gold word highlight ESTIMATED from playback progress.
- [ ] Re-narrate flow: regenerate audio from stored `story` text when local audio missing. Needs a backend re-narrate path (or reuse createStoryJob). Separate from follow-along.
- [ ] Follow-along: TRUE per-word sync needs ElevenLabs word timestamps (current highlight is a progress estimate).
### Screens
- [x] Kid Home (s5) — rebuilt on StTile/StRow + resume strip. (No bottom TabBar — re-checked wireframe s5, it has none; earlier "missing TabBar" was a misread.)
- [x] Wizard: Character (s6) — StChoiceCard/StDots
- [x] Wizard: Scene (s7)
- [x] Wizard: Theme (s8)
- [x] Wizard: Twist (s9)
- [x] Wizard: Narrator (s10) — built-in voices only (family voices later)
- [x] Wizard: Review (s11)
- [x] Generating (s12b) — bedtime theme, bound to job status
- [x] Story Player (s12) — StScenePlayer transport + follow-along text with gold highlight. VERIFIED playing "The Brave Little Fox" on sim.
- [x] End screen (s13) — bedtime theme
- [~] Library (s11b) — list + re-listen done (StRow); re-narrate pending local story text

## Milestone 3 — Onboarding, account, parent area
- [x] Splash (s1) + Welcome (s2) — rebuilt, bedtime/day
- [x] Create account / sign-in (s2) — StTextField/StButton, Firebase Auth (lifted)
- [~] Add child (s3) — rebuilt (StSegment age band); stored in SharedPreferences, NOT Firestore yet
- [ ] Add-a-voice invite (s4) — MISSING (only FamilyVoicesTeaser exists)
- [x] Parent gate (s17) — KEPT the age-verify + PIN gate (stronger than wireframe's "hold the dot"). Re-skinned AgeGate + PinGate + ChangePin + ParentAccess onto the design system (logic byte-for-byte unchanged). VERIFIED on sim: PIN gate shows cream card, "GROWN-UPS ONLY" eyebrow, Fraunces title, token keypad. `StParentGate` component left available but unused (lacks lockout/attempt hooks).
- [x] Parent dashboard (s18) — StRow entries
- [~] Content & safety (s19) — currently diagnostics/privacy only. Wireframe wants: Story length (Short/Med/Long seg), Safe-content filter / Bedtime mode / Daily time limit toggles, Save. NEEDS PRODUCT DEFINITION before building — each control must DO something (story length → generation word count; bedtime → ?; daily limit → playback gate). Don't ship dead toggles. Backend safety is always-on (two-pass), so a "filter off" toggle is questionable. Deferred pending product decisions.
- [x] Account deletion wired to `deleteAccountData` (lifted)

## Milestone 4 — Family voice tier (cloning)

### Frozen contract (2026-06-26 — team-lead decisions; build against these)
- **Encoding:** family voice rides the existing `narratorKey` as `family:<voiceId>` (built-ins keep enum names `wizardWally|fairyFern|roboRay`). One field, smallest diff.
- **Firestore data model — `users/{uid}/voices/{voiceId}`** (server-written; client read-only):
  `{ name, relationship, subjectLiving: bool, consent: { agreedByUid, agreedAt, relationship, subjectLiving }, status: "consented"|"queued"|"cloning"|"ready"|"failed", samplePaths: string[], providerVoiceId?, errorCode?, createdAt, updatedAt }`
- **Voice samples in Storage:** `voice-samples/{uid}/{voiceId}/{idx}.m4a` — client uploads directly; only server reads.
- **State machine:** `createVoiceConsent` → doc `status:"consented"` (returns voiceId). Client uploads samples to Storage. `submitVoiceClone({voiceId, samplePaths})` callable validates (consent present + ≥1 sample exists + entitled) → sets `status:"queued"`. `processVoiceClone` = `onDocumentUpdated` on the voice doc, guard `before.status!=="queued" && after.status==="queued"`.
- **Idempotency (clone leaks an external resource):** re-read status in the trigger; if `providerVoiceId` already set → skip. Write `providerVoiceId` BEFORE flipping to `ready`. On ElevenLabs error → `status:"failed"` + `errorCode` (mirror story-job failure handling). ElevenLabs accounts have voice-slot limits → clone can 4xx.
- **Server-side trust (NON-NEGOTIABLE):** `createStoryJob` — if `narratorKey` matches `family:<id>`, look up `users/{uid}/voices/{id}`, require `exists && status==="ready"` AND entitlement, else `invalid-argument`. `domain.ts` relaxes the static narrator check to accept `family:<id>` shape; the existence/status/entitlement check lives in `index.ts` (Firestore, not pure domain).
- **`synthesize()` becomes async-lookup:** if `narratorKey` is `family:<id>`, read `users/{uid}/voices/{id}.providerVoiceId` (uid = `event.params.uid` in `processStoryJob`); else the built-in secret map.
- **Entitlement:** `storytimeConfig/familyVoice` doc, `enabled` field. Missing/true = ON (default-on for testing). Checked in `submitVoiceClone` AND `createStoryJob` family path. A real flag the launch billing gate flips.
- **ElevenLabs API (verified 2026-06-26):** add = `POST /v1/voices/add`, multipart/form-data, fields `files` (audio), `name`, optional `description`/`labels`/`remove_background_noise`; response `{ voice_id, requires_verification }`. Delete = `DELETE /v1/voices/{voice_id}`. Header `xi-api-key` (reuse `ELEVENLABS_API_KEY` secret).
- **Testing posture:** live ElevenLabs in manual e2e; mocked in unit tests.

### Backend (new) — ✅ implemented (commit `feat(M4) backend`); lint clean, 8/8 tests
- [x] `createVoiceConsent` — store consent (who, when, relationship, living?) — gate everything on it
- [x] `submitVoiceClone` intake — validates consent+samples+entitlement → status `queued` (samples uploaded client-side to Storage)
- [x] `processVoiceClone` (`onDocumentUpdated` trigger) — ElevenLabs voice-add → `providerVoiceId` (written BEFORE `ready`); idempotent; failed-path
- [x] `deleteVoice` — DELETE ElevenLabs voice + Storage samples + doc (real)
- [x] Extend `synthesize()` to resolve family `narratorKey` → `providerVoiceId` (lookup, uid from event)
- [x] `entitlement` flag check (`storytimeConfig/familyVoice.enabled`, default-on) gating clone + family-voice narration
- [x] `deleteAccountData` purges ElevenLabs voices + voice samples
### Screens — ✅ implemented (commit `feat(M4) screens`); `flutter analyze` 0 errors
- [x] Voices list (s20) — `FamilyVoicesScreen` (replaces waitlist teaser)
- [x] Consent (s21) — `VoiceConsentScreen`
- [x] Upload a clip (s21u) — `VoiceUploadScreen`
- [x] Capture intro (s23) — `VoiceCaptureIntroScreen`
- [x] Guided capture (s24) — `GuidedCaptureScreen`, 5 prompted tones
- [x] Voice ready (s22) — `VoiceReadyScreen` (live status subscription)
- [x] Family voices appear in narrator picker (s10) alongside built-ins (`StoryDraft.familyVoiceId` → `family:<id>`)

**M4 verification status (2026-06-26):**
- ✅ Static: backend lint + 8 unit tests; `flutter analyze` 0 errors. App **boots healthy on sim with new `firebase_storage` pod** (home renders; the firebase_storage native-dep integration was the main risk and it's clear).
- ✅ **e2e VERIFIED on emulators (2026-06-26):** ran the `processVoiceClone` trigger pipeline against the Firebase Emulator Suite with a mocked ElevenLabs (`functions/dev/`, see its README). `consented→queued→cloning→ready` with `providerVoiceId` set; the mock confirmed receiving the multipart sample payload. So the highest-risk untested glue — Storage download + `FormData`/`Blob` multipart + state machine + atomic ready write — is proven. (Found a real env quirk: emulator default bucket is `appspot.com`, not the app's `firebasestorage.app`; no prod impact — documented in dev/README.)
- ⏳ NOT exercised by the harness: the **App Check-enforced callables** (`createVoiceConsent`/`submitVoiceClone`/`createStoryJob` family validation) — the emulator can't mint valid App Check tokens. Their synchronous validation logic is covered by `domain.test.ts` + review; full callable e2e needs the Flutter client pointed at the emulators (or a prod deploy + registered App Check debug token).
- 🔒 Idempotency hardened (commit `fix(M4)`): `processVoiceClone` success write is atomic and the retry early-return finalizes to `ready`, so a crash mid-clone can't strand a voice at `cloning`. No `narratorKey!` force-unwraps exist in `app/lib` (family-voice cards with null narrator are safe).
- 🐛 Fixed during integration: (1) ElevenLabs sample upload used `buffer.buffer` (pooled-ArrayBuffer over-read) → tight `Uint8Array` copy. (2) `StoryJob.narratorKey` was non-null `byName` → would **crash the job read** for `family:<id>` jobs → made nullable + safe-parse.
- 🧹 Follow-up: dead `FamilyVoicesTeaserScreen` class + `joinFamilyVoiceWaitlist` callable/repo method are now unrouted; remove once the live flow is confirmed.

## Milestone 5 — Hardening
- [ ] Firestore + Storage security rules (user-scoped; server-written status fields)
- [ ] App Check enforced end-to-end on all callables (verified on device)
- [ ] Offline playback of imported stories verified
- [ ] Audio TTL / `cleanupExpiredStoryAudio` verified (audio gone, story text retained)
- [ ] Quota enforcement + failure refund verified
- [ ] Account deletion verified (Firestore + Storage + ElevenLabs all purged)

## Launch gates (NOT testing — see plan §7)
- [ ] Billing provider chosen + IAP integrated; replace `$0` entitlement flag
- [ ] Biometric consent disclosure in privacy policy; ElevenLabs named as processor
- [ ] Deceased-person consent policy (next-of-kin attestation) + legal sign-off
- [ ] Geographic gating for Family voice tier decided

---

## codex/v2 audit outcome (2026-06-25)
codex/v2 = main + 1 commit. Audit verdict + recommended path: **keep `main` as base; LIFT backend + wiring from codex/v2; DISCARD its theme + screens; rebuild screens on the `St*` component library.**

**Lift from codex/v2 (good, reusable):**
- Backend: `functions/src/{index,domain,domain.test}.ts`, `functions/{package.json,tsconfig.json}`
- Rules/config: `firestore.rules`, `storage.rules`, `firebase.json`, `firestore.indexes.json`
- Models: `app/lib/models/storytime_models.dart` (enums + StoryDraft — perfectly match domain.ts), `audio_card.dart` (new fields: storyOrigin, narratorKey, isFavorite, durationMs, lastPlayedAt, mediaType)
- Services: `story_generation_repository.dart` (callable + job stream), `active_story_job_service`, `child_profile_service`, `auth_repository`, `narrator_preview_service`, `starter_story_service`, `storytime_migration_service`, `key_value_store`, `analytics_service`
- `app/lib/providers/storytime_providers.dart`; `app/lib/router.dart` (route STRUCTURE only)
- Assets: `app/assets/storytime/*` (starter WAVs + previews + starter_stories.json) — NOTE ~14MB WAVs, watch APK size
- Client routes generation via `createStoryJob` + Firestore job stream; on-device Anthropic key/path DELETED (good). Client enums match backend exactly.

**Discard from codex/v2:** `app/lib/theme/storytime_theme.dart` (purple #6657D9 palette, no day/bedtime — superseded by our `app_theme.dart`); `app/lib/ui/storytime_screens.dart` (2110 lines, zero component reuse, wrong palette — rebuild with `St*` components).

**MUST-FIX before/within M2 (audit-found):**
1. `processStoryJob` does NOT write `story` text to job doc → Decision B broken. Add `story: story.story`. Re-narration + follow-along player depend on it.
2. Daily quota: code defaults to **3** and uses key `dailyLimit`; plan says **10** / key `dailyQuota`. Reconcile naming + value.
3. `database_service.dart` SQLite schema migration adds columns (storyOrigin, narratorKey, isFavorite, durationMs, lastPlayedAt) — port carefully or on-device cards are lost. AUDIT before shipping.
4. Child profile stored in SharedPreferences, not Firestore — reinstall loses it. Plan wants `users/{uid}/child`.
5. `confirmStoryImported` deletes Storage audio immediately on import with no retry if local write fails — harden.

**codex/v2 screen coverage:** 13 full / 4 partial / 7 missing. Missing = s4 + all Family voice s20–s24 (only a `FamilyVoicesTeaserScreen` waitlist exists). Partial: s5 (no TabBar), s10 (no family voices), s12 (no follow-along text), s19 (diagnostics only, no content-safety levels).
**codex/v2 extras not in plan:** migration service, starter stories seeding, narrator preview WAVs, favorites (isFavorite/lastPlayedAt), age gate, crashlytics opt-in.

## Build / env gotchas
- Flutter: `export PATH="$HOME/Downloads/flutter/bin:$PATH"`. Default shell node is v16 (too old for functions/vitest) → `nvm use 22` for backend.
- iOS CocoaPods on this toolchain (Ruby 3.4): MUST `export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8` or `pod install` crashes (Encoding::CompatibilityError). Firebase pods needed a fresh resolve (`rm Podfile.lock Pods/ && pod install`). Podfile.lock committed.
- ✅ Full app VERIFIED running on iOS sim (iPhone 17 Pro): Kid Home (s5), wizard Character (s6), Library (s11b), and Story Player (s12, dark, follow-along text + gold highlight, audio playing) all render correctly on the design system. Firebase init + routing + starter-story seeding (6 stories) work. To reach the player on sim do a CLEAN install (`simctl uninstall com.shiru.app`) first — stale audio paths otherwise (see Bugs).

## Bugs / quirks found during verification (2026-06-25)
- [x] **Audio path breaks across reinstalls** — FIXED. `AppPaths` (`services/app_paths.dart`) caches docs dir (init in `main()`); `AudioCard.fromMap` resolves stored value → current-container absolute, `toMap` relativizes → basename. In-memory paths stay absolute (consumers unchanged); `resolve()` self-heals legacy absolute rows. Verified non-regressive on sim (existing library still plays).
- ~~Home greets "Hi MMMM!"~~ NOT a bug. `KeyValueStore` = `flutter_secure_storage` (keychain) and Firebase Auth both persist in the iOS keychain, which survives `simctl uninstall`. "MMMM" is leftover test data from a prior child-setup. Launch routing IS correct (null user→/welcome, null child→/child-setup). To actually test onboarding: sign out (parent → account) or wipe keychain. (Code even has a comment re: stale keychain entries across reinstalls — `key_value_store.dart:35`.)
- Note: yoto.db is ENCRYPTED (sqflite + cipher) — can't inspect with plain `sqlite3`.
- ⚠️ Onboarding RENDERING verified (Auth/Create-account s2 confirmed on design system via throwaway entrypoint — StTextField, ember CTA, Apple/Google ghost buttons, disclaimer). Full INTERACTIVE flow (welcome→auth→child-setup→home, actually creating an account) still not run end-to-end — blocked by persisted keychain test account. To test: sign out (parent→account) or erase sim keychain.

## Notes / scratch (update freely across sessions)
- _Decision B requires `story` text on job doc — see Milestone 2 backend tasks + must-fix #1 above._
- _Testing-phase voice rule: only living, consenting voices; verify delete purges ElevenLabs + Storage._
