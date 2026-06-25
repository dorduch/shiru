# Storytime MVP — Task Tracker

> Durable task list. Companion to [storytime-mvp-plan.md](storytime-mvp-plan.md). Update checkboxes as work progresses. Status legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked.

**Locked decisions (do not re-litigate):**
- Billing deferred → `$0` testing; Family features behind a free-on `entitlement` flag.
- Quota → 10 stories/day/user (`storytimeConfig/generation.dailyQuota`, server-tunable).
- `narratorKey` = built-in enum **or** ref to `users/{uid}/voices/{id}`; server resolves both.
- Persistence **B** → story text durable in Firestore; audio is a cache (device-primary, cloud-ephemeral).
- Design direction = attached Storytime wireframes + landing (re-skin off legacy Shiru).
- Backend foundation = existing `functions/` dir (from codex/v2); extend, don't rewrite.

**Current focus:** On branch `feature/storytime-mvp` (uncommitted: M1 design system + lifted backend). ✅ M1 design system done+verified. ✅ codex/v2 audited → keep main, lift backend/wiring, rebuild screens on `St*`. ✅ Backend lifted from codex/v2 + must-fixes #1 (story text) & #2 (quota→10) applied; build clean + tests 4/4 (use `nvm use 22`). ▶ NEXT: lift client wiring (models/services/providers) from codex/v2 AND rebuild M2/M3 screens on the component library + reconcile router (discard codex/v2's `storytime_theme.dart` + `storytime_screens.dart`). These must land together — screens+router+wiring are mutually dependent for compile. flutter at `$HOME/Downloads/flutter/bin`.

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
- [ ] Mirror domain enums (character/scene/theme/plot/narrator/ageBand) on client from `domain.js`
- [ ] Route generation through `createStoryJob` callable (App Check) — stop using on-device `StoryService.callClaudeApi`
- [ ] Remove/disable on-device Anthropic key path (release blocker)
- [ ] Job-stream provider subscribing to `users/{uid}/storyJobs/{jobId}`; map states queued→writing→checking→narrating→ready/failed
- [ ] On `ready`: download audio, save locally (SQLite/files), call `confirmStoryImported`
- [ ] Re-narrate flow: regenerate audio from stored `story` text when local audio missing (decision B)
### Screens
- [ ] Kid Home (s5)
- [ ] Wizard: Character (s6)
- [ ] Wizard: Scene (s7)
- [ ] Wizard: Theme (s8)
- [ ] Wizard: Twist (s9)
- [ ] Wizard: Narrator (s10) — built-in voices only for now
- [ ] Wizard: Review (s11)
- [ ] Generating (s12b) — bound to job status
- [ ] Story Player (s12) — follow-along text + transport
- [ ] End screen (s13)
- [ ] Library (s11b) — list durable stories, re-listen / re-narrate

## Milestone 3 — Onboarding, account, parent area
- [ ] Splash / Welcome (s1)
- [ ] Create account (s2) — Firebase Auth
- [ ] Add child (s3) — `users/{uid}/child` { name, ageBand }
- [ ] Add-a-voice invite (s4) — entry to Family flow (can be soft/teaser pre-Family)
- [ ] Parent gate (s17)
- [ ] Parent dashboard / Settings (s18)
- [ ] Content & safety settings (s19)
- [ ] Account deletion wired to `deleteAccountData`

## Milestone 4 — Family voice tier (cloning)
### Backend (new)
- [ ] `createVoiceConsent` — store consent (who, when, relationship, living?) — gate everything on it
- [ ] `startVoiceCapture` / upload intake — guided 5-line capture or ~1min clip → Storage under user prefix
- [ ] `processVoiceClone` (trigger) — call ElevenLabs voice-add → store `providerVoiceId` on `users/{uid}/voices/{id}`, status ready
- [ ] `deleteVoice` — delete ElevenLabs voice + samples + doc (must be real, not a hide)
- [ ] Extend `synthesize()` to resolve family `narratorKey` → `providerVoiceId`
- [ ] `entitlement` flag check (free-on during testing) gating clone + family-voice narration
- [ ] Ensure `deleteAccountData` purges ElevenLabs voices + voice samples
### Screens
- [ ] Voices list (s20)
- [ ] Consent (s21)
- [ ] Upload a clip (s21u)
- [ ] Capture intro (s23)
- [ ] Guided capture (s24) — 5 prompted lines, tones
- [ ] Voice ready (s22)
- [ ] Family voices appear in narrator picker (s10) alongside built-ins

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

## Notes / scratch (update freely across sessions)
- _Decision B requires `story` text on job doc — see Milestone 2 backend tasks + must-fix #1 above._
- _Testing-phase voice rule: only living, consenting voices; verify delete purges ElevenLabs + Storage._
