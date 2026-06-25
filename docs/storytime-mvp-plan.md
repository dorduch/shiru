# Storytime — MVP Implementation Plan

**Scope of this document:** the two things that gate the MVP — the **API layer** (story generation, narration, voice, account) and the **design system** (tokens + components derived from the attached wireframes and landing page). Screen-by-screen UI build and infra/devops are referenced but not exhaustively specified here.

Source of truth:
- **Product/visual direction:** `Storytime_Landing.html` (marketing) and `Storytime_Wireframes.html` (24 app screens). These supersede the legacy Shiru pixel-art aesthetic — the app is being re-skinned to the Storytime "warm night" language.
- **Backend foundation:** the `functions/` directory currently in the tree (from `codex/v2`). It already implements the async story-generation pipeline; the plan extends it rather than starting fresh.

---

## 1. Product in one paragraph

A bedtime-story app for ages 2–8. A parent creates a short story in a few taps (character → place → theme → twist → narrator); the backend writes it with Claude, runs it through a kid-safety review, narrates it with ElevenLabs TTS, and the child listens with follow-along text. **Free tier** uses built-in narrator voices. **Family tier ($9/mo)** lets a family clone a loved one's real voice (captured in-app or uploaded) so new stories are read aloud in *their* voice — the emotional core of the product.

---

## 2. Architecture overview

```
Flutter app  ──App Check──►  Firebase
  │                            ├─ Auth (account, child profile)
  │                            ├─ Cloud Functions (callable + triggered)
  │                            │     createStoryJob ──► Firestore job doc
  │                            │     processStoryJob (onCreate) ──► Anthropic + ElevenLabs ──► Storage
  │                            ├─ Firestore (jobs, usage/quota, voices, config)
  │                            └─ Storage (generated audio, voice samples)
  └─ local SQLite (sqflite): imported stories played offline
```

Key principle already established in `functions/lib/index.js`: **generation is asynchronous via a Firestore-backed job, not a blocking HTTP call.** The client writes a job request through a callable, a Firestore trigger does the slow work (LLM + TTS), and the client subscribes to the job document for status. Keep this; it survives app backgrounding and gives a natural progress UI (the "Writing your story…" screen).

---

## 3. API layer

### 3.1 Cloud Functions surface (existing — keep)

| Function | Type | Purpose | Status |
|---|---|---|---|
| `createStoryJob` | callable, App Check | Validates input, enforces daily quota in a transaction, writes a `queued` job doc | ✅ exists |
| `processStoryJob` | Firestore `onCreate` | Runs the generate → safety → narrate → store pipeline, updates job status | ✅ exists |
| `confirmStoryImported` | callable | Client confirms it downloaded the audio; server deletes the Storage object + URL | ✅ exists |
| `joinFamilyVoiceWaitlist` | callable | Records interest in the Family voice tier | ✅ exists (placeholder for real cloning) |
| `deleteAccountData` | callable | `recursiveDelete` of user doc + waitlist + storage prefix | ✅ exists |
| `cleanupExpiredStoryAudio` | scheduled (6h) | Deletes audio past `expiresAt`, clears URLs | ✅ exists |

### 3.2 Job state machine (the contract the client renders against)

```
queued → writing → checking → narrating → ready
                                  └────────────► failed (errorCode)
```

The client subscribes to `users/{uid}/storyJobs/{jobId}` and maps:
- `writing`/`checking`/`narrating` → the dark "Generating" screen (s12b)
- `ready` → download `downloadUrl`, save locally, then call `confirmStoryImported`, navigate to player (s12)
- `failed` → friendly retry; quota was already refunded server-side on failure

### 3.3 Firestore data model

```
users/{uid}
  child            { name, ageBand }          // ageBand ∈ early|middle|older
  storyJobs/{id}   { ...input, status, title, story, downloadUrl, storagePath,
                     remaining, quotaDay, expiresAt, imported, errorCode, timestamps }
                   // `story` (full text) persists permanently for re-narration (decision B);
                   // only downloadUrl/storagePath/expiresAt are cleared when audio expires
  generationUsage/{utcDay}  { reserved }       // quota counter, transactional
  voices/{voiceId} { label, relationship, source, consent, providerVoiceId,
                     status, createdAt }        // NEW — Family tier
storytimeConfig/generation  { dailyQuota, ... } // server-tunable config
familyVoiceWaitlist/{uid}                        // legacy/free-tier interest
```

Story input domain (locked in `functions/lib/domain.js`, mirror it on the client):
`character`, `scene`, `theme`, `plot`, `narratorKey` (`wizardWally|fairyFern|roboRay`), `ageBand` (`early|middle|older`). **The client must never invent choices** — it picks from these enums; the server re-validates and rejects anything off-list.

### 3.4 External APIs

**Anthropic — story generation + safety (two calls per job):**
- Model `claude-haiku-4-5-20251001`, `anthropic-version: 2023-06-01`, key via `defineSecret("ANTHROPIC_API_KEY")`.
- Call 1: `storyPrompt(input)` → JSON `{ title, story }`, length scaled by `wordCountFor(ageBand)`.
- Call 2: independent safety review prompt (sexual content, graphic violence, self-harm, abuse) → pass/fail; on fail, retry generation once with a stricter prompt before failing the job. **Keep this two-pass design — it is the trust story the landing page sells.**

**ElevenLabs — narration:**
- `POST https://api.elevenlabs.io/v1/text-to-speech/{voiceId}`, key via `defineSecret`.
- Built-in narrators map to three secret voice IDs (`ELEVENLABS_VOICE_WALLY|FERN|RAY`). Audio is written to Storage at `story-jobs/{uid}/{jobId}...`, a signed/download URL stored on the job, with a TTL (`expiresAt`) so generated audio is ephemeral once imported to the device.

### 3.5 The Family-tier gap: voice cloning (NEW work)

Today only a **waitlist** exists. MVP-for-Family needs the real path. Wireframes define three sub-flows (consent → capture/upload → ready): screens s20–s24.

Proposed API additions (new callables + a trigger, mirroring the story-job pattern):

| Function | Purpose |
|---|---|
| `createVoiceConsent` | Record explicit consent ("X agrees to share their voice"), relationship label, and whether the subject is living. Gate everything else on this. |
| `startVoiceCapture` / upload | Accept either (a) guided capture: 5 short prompted lines in varied tones (s24), or (b) an uploaded clip (~1 min, s21u). Store raw samples in Storage under the user prefix. |
| `processVoiceClone` (Storage/Firestore trigger) | Call ElevenLabs **voice add / instant voice cloning** API with the samples → store the returned `providerVoiceId` on `users/{uid}/voices/{id}`, set `status: ready`. |
| `deleteVoice` | Delete the ElevenLabs voice + samples + doc. Surfaced as "delete anytime" in UI. |

Then `synthesize()` in `processStoryJob` extends its narrator→voiceId map to also resolve **family voices**: if `narratorKey` references a `users/{uid}/voices/{id}`, use that `providerVoiceId` instead of a built-in secret.

**Hard requirements before this ships:**
- Consent capture is mandatory and auditable (store who/when).
- Family tier entitlement check (billing) before allowing cloning and family-voice narration.
- Samples and cloned voices are deletable and are removed by `deleteAccountData`.

### 3.6 Client service layer (Flutter)

Existing services largely map already: `story_service.dart`, `elevenlabs_service.dart`, `recording_service.dart`, `audio_service.dart`, `auth_provider`, `recording_provider`. Refactor target:
- **Generation should go through the callable + job subscription**, not the client's direct `callClaudeApi` path (that path keeps the Anthropic key on-device — fine for a playground, not for production). Treat the on-device `StoryService.callClaudeApi` as dev-only and route production through `createStoryJob`.
- Add a `VoiceRepository` for the s20–s24 flows and a job/voice stream provider per the state machines above.

### 3.7 Security / platform

- **App Check enforced** on every callable — keep `enforceAppCheck: true`.
- Auth required (`request.auth.uid`) on all user-scoped functions.
- All third-party keys live in `defineSecret`, never in the client. Migrating the on-device Anthropic key out is a release blocker.
- Firestore/Storage security rules: a user can read/write only under `users/{uid}/…`; jobs are server-written for status fields.

---

## 4. Design system

Derived **directly from the attached files.** The app uses the wireframe token set (`Storytime_Wireframes.html`); the landing page is a slightly warmer marketing variant of the same language. One system, two surfaces.

### 4.1 Color tokens (canonical = app)

| Token | App value | Role |
|---|---|---|
| `night-1 / 2 / 3` | `#171228` `#2A1B3D` `#5B2E48` | Dark "bedtime" gradient (player, capture, splash) |
| `dusk` / `ember` | `#9C4A4A` / `#E2885A` | Warm dusk accents |
| `cream` / `paper` | `#FBF6EE` / `#FFFDF9` | Light surfaces |
| `ink / ink-2 / ink-3` | `#241F2E` `#5C5566` `#A49CB2` | Text primary / secondary / tertiary |
| `accent` / `accent-2` | `#E08A5B` / `#C9685A` | Ember CTA gradient |
| `gold` | `#E9B873` | Highlight, follow-along word, "voice" moments |
| `line` / `line2` | `#EBE2D4` / `#DDD2C2` | Borders / dividers |

Landing-page variants (use only on marketing web): deeper `night-1 #241433`, `ivory #FBF3E8`, `accent-2 #D2685A`, `gold #EBB877`. Keep these in a separate `marketing` token scope so the app palette stays single-sourced.

### 4.2 Typography

- **Display/headings:** Fraunces (serif), weight 400–600, tight tracking `-.01em`, line-height 1.1. Used for titles, story text, emotional copy.
- **UI/body:** Inter, 400–600. Used for buttons, labels, secondary copy.
- Eyebrow style: Inter 600, 11px, `letter-spacing .18em`, uppercase, `accent-2`.
- Story/read text uses Fraunces 400 at ~17px/1.85 with a gold "currently-spoken" highlight token.

### 4.3 Spacing, radius, elevation

- Radius scale from the mockups: inputs/buttons `14–16px`, cards `16–20px`, tiles `20px`, sheets/screens `36–46px`, pills `100px`.
- Elevation: soft warm shadows (`0 10px 24px rgba(201,104,90,.3)` for ember CTA; `0 40px 100px rgba(0,0,0,.5)` for the device/bedtime depth).
- Two surface modes: **Light ("day")** for setup/parent/library; **Dark ("bedtime")** gradient for splash, generating, player, end, and voice capture.

### 4.4 Component inventory (build as a shared widget library)

Each maps to a class in the wireframes — these become reusable Flutter widgets:

| Component | Variants | Seen in |
|---|---|---|
| `Button` | ember (primary gradient), dark, ghost, line, soft | everywhere |
| `Input` / `Field` | text input, empty field | account, add child |
| `ChoiceCard` | default / selected, with pixel-art thumbnail | wizard character/scene/theme/twist |
| `Tile` | standard / big, colored, label + sublabel | kid home, narrator |
| `Row` | avatar + title + sub + trailing (lock / chevron / "soon") | voices, settings, library |
| `Eyebrow` + `Title` + `Sub` | section header trio | most screens |
| `Dots` | progress (wizard step indicator) | wizard |
| `Seg` | segmented control | content & safety |
| `Toggle` | switch on/off | settings |
| `Hint` | warm advisory note | wizard, capture |
| `Chip` / `Tonechip` / `Lock` / `TagSoon` | status pills | voices, narrator, capture |
| `CaptureRing` + `Prompt` + `RecordButton` + `VoiceWave` | guided voice capture | s23–s24 |
| `ScenePlayer` | dark art panel, follow-along text, transport controls, progress bar | story player |
| `TabBar` | bottom nav (Home / Listen / …) | kid zone |
| `ParentGate` | PIN/grown-ups-only entry | s17 |

### 4.5 Pixel-art reuse

The wireframes still render small pixel sprites in choice cards (`.px`, `image-rendering:pixelated`). Reuse the existing `PixelSprite` renderer and `SpriteDef` library for character/scene/theme thumbnails — it survives the re-skin and gives the wizard its playful, kid-readable choices.

### 4.6 Theming implementation

Define a single `StorytimeTheme` (ThemeData + extension for the custom tokens above) with `day` and `bedtime` color schemes. Every screen declares which mode it uses (the wireframes already split this cleanly via the `.dark` class). No ad-hoc colors in widgets — all from tokens.

---

## 5. Build sequence

1. **Design system first.** Tokens + the component library in §4.4, in both day/bedtime modes, with a widgetbook/gallery screen. Everything else consumes this.
2. **Story generation path (free tier), production-grade.** Route the client through `createStoryJob` + job-stream provider; build wizard (s6–s11), generating (s12b), player (s12), end (s13), library (s11b). Retire the on-device Anthropic key.
3. **Onboarding + account + child profile** (s1–s3), parent gate (s17), dashboard (s18), content & safety (s19).
4. **Family voice tier.** Consent + capture/upload + clone pipeline (§3.5) and family-voice narration; billing/entitlement gate; voices management (s20–s24, s22).
5. **Hardening:** security rules, App Check end-to-end, account deletion, audio TTL/cleanup verification, offline playback of imported stories.

---

## 6. Decisions

- **Billing → deferred. $0 for the testing phase.** No provider chosen. Family-tier features are gated behind a simple `entitlement` flag that is free-on during testing; a real IAP/RevenueCat/Stripe integration swaps in later without touching the feature code. Do not commit to a provider now.
- **Quota → 10 stories/day/user**, stored in `storytimeConfig/generation.dailyQuota`, server-tunable. Haiku generation is cheap; ElevenLabs TTS is the real cost. Start here and adjust from telemetry.
- **Narrator ↔ family voice → one field.** `narratorKey` is either a built-in enum (`wizardWally|fairyFern|roboRay`) **or** a reference to `users/{uid}/voices/{id}`. The s10 "Whose voice tells it?" list shows both together. Server `synthesize()` resolves: built-in → secret voiceId; otherwise look up the voice doc → `providerVoiceId`. `validateStoryRequest` is extended to also accept family-voice IDs the requesting user owns.
- **Story persistence → option B (decided).** Persist the *story record* (title, text, choices, voice reference) permanently in Firestore; treat **audio as a cache** — primary on device, ephemeral in cloud (current TTL behavior). Re-listen on the same device is instant; a new device re-narrates on demand (one ElevenLabs call). This honors the "keep it for years / a memory that grows" product promise without warehousing audio or holding voice recordings in the cloud. (Alternative C — permanent cloud audio for instant cross-device — only if that UX is worth the storage cost and longer audio retention.)

## 7. Legal / compliance gates (pre-public-launch, NOT testing)

Voice cloning touches biometric data — these block public launch but not internal/tester use of living, consenting voices:
- **Biometric consent & disclosure**: voiceprints fall under BIPA (IL), CUBI (TX), GDPR (EU). Need explicit informed consent capture (already in `createVoiceConsent`), privacy-policy disclosure of ElevenLabs as processor, and a working deletion path.
- **Deletion must be real**: `deleteVoice` and `deleteAccountData` must call ElevenLabs' delete API and purge Storage samples — not just hide rows. Losing the voice→`providerVoiceId` mapping = biometric data we can't honor deletion on.
- **Deceased-person policy**: the "someone no longer here" use case has no first-party consent. Requires a next-of-kin attestation flow + legal sign-off before it's public.
- **Geographic gating**: decide which states/countries the Family voice tier is offered in at launch.

**Testing-phase rule:** clone only living, consenting voices (team / tester families); store the consent record; verify delete purges ElevenLabs + Storage. Defer the legal review to the launch milestone.
