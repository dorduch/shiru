# Voice invite flow — spec (draft)

Date: 2026-07-11
Status: draft / not yet decided — for product review

## Problem / motivation

Family Voices today only works if the person whose voice is being cloned sits down
with the parent's phone and records inside the Shiru app. That excludes the most
common real case: a grandparent or other relative who doesn't have the app, may be
far away, and isn't going to install a kids' storytelling app just to read five
prompts aloud. "Voice invite" was named early in this project (`docs/storytime-mvp-tasks.md`
tracks it as screen `s4`, still unbuilt) as the fix: a link the parent can text or
email, that opens a recording page in any browser, no install required, feeding the
exact same voice-cloning pipeline Family Voices already uses.

## Proposed high-level flow

1. Parent, inside the app (Family Voices flow), taps "Invite someone to record"
   instead of "Record now" / "Upload a clip".
2. App/backend generates a single-use invite link tied to that parent's account and
   a specific in-progress voice (name, relationship, consent already captured
   in-app, same as today's `createVoiceConsent` step).
3. Parent sends the link via their own text/email/whatever — Shiru doesn't need to
   sms/email on its own behalf initially (though it could later).
4. Recipient opens the link in a mobile or desktop browser. No account, no app
   install, no Firebase Auth sign-in.
5. Recipient sees a simple page: who the recording is for, a short explanation, and
   the same guided prompts (or upload option) used in-app today.
6. Recipient records N samples (reuse the existing 5-prompt guided script for
   parity in clone quality) and submits.
7. Samples land in the same place the in-app flow puts them, feeding the existing
   `submitVoiceClone` → `processVoiceClone` → ElevenLabs pipeline, unmodified.
8. Parent sees the voice progress to "ready" in-app exactly as they do today
   (`VoiceReadyScreen`), regardless of which capture path fed it.

## What's reused vs. net-new

**Reused as-is:**
- The Firestore data model (`users/{uid}/voices/{voiceId}`), its status machine, and
  `processVoiceClone` (ElevenLabs call, idempotency, failure handling).
- The Storage path convention `voice-samples/{uid}/{voiceId}/{idx}.m4a`.
- The consent capture step and copy (name, relationship, living/deceased toggle,
  agreement checkbox) — done in-app before the link is generated.
- The 5 guided prompts (tone + text) for capture parity with the in-app flow.
- `deleteVoice` / account-deletion purge paths — no change needed.

**Net-new (this is most of the work):**
- **A web frontend** — a lightweight, mobile-and-desktop-friendly recording page
  hosted somewhere reachable without the app (framework/hosting TBD, see open
  questions).
- **Invite-link generation and storage** — something in-app that creates a
  single-use token/link scoped to `{uid, voiceId}`, stores it server-side, and
  exposes it to the parent to share.
- **A new authorization bridge for the web path.** Today every backend call
  requires a real Firebase Auth `uid` *and* an App Check token, and Storage writes
  are gated on `request.auth.uid == uid`. A browser recipient with no app and no
  account has none of these. Something has to stand in for that trust boundary —
  e.g. a server-minted custom auth token scoped to the invite, or a new
  unauthenticated HTTPS function that trades a valid invite token for permission
  to write to `voice-samples/{uid}/{voiceId}/...` and to flip status to `queued`.
  This is the crux of the feature, not a side detail.
- **Link expiry / single-use enforcement** — a link that works once, or for a
  bounded window, so it can't be replayed or forwarded indefinitely.
- **Associating uploaded samples with the right family/child** — because voices
  are account-level (`users/{uid}/voices/{voiceId}`), the invite token needs to
  resolve unambiguously to that same `{uid, voiceId}` pair so samples land where
  `processVoiceClone` expects them, without exposing the raw uid/voiceId in a
  guessable way.

## Open questions (flag, don't decide here)

- **Web stack/hosting.** Static page (e.g. Firebase Hosting) vs. something with its
  own small backend? Does it need server-side logic at all, or can invite
  validation + upload be handled entirely through Cloud Functions HTTPS endpoints?
- **Link lifetime.** How long does an invite stay valid — hours, days, until first
  use, until the voice record is deleted? What happens if the parent needs to
  resend it?
- **Auth/authorization mechanism for the unauthenticated recipient.** Custom
  Firebase Auth token minted server-side and scoped to the invite? A bespoke
  token-validated HTTPS function bypassing App Check/Firebase Auth entirely for
  this one path? Something else? This has real security tradeoffs (a leaked link
  becoming a way to write arbitrary audio into someone's voice-clone pipeline) and
  needs a decision before implementation.
- **Consent semantics shift.** In-app, the *parent* asserts consent on the
  subject's behalf (`agreedByUid` = parent uid) before capture even starts. In the
  web flow, the actual subject (the grandparent) is the one opening the link and
  recording — arguably stronger consent, but a different consent record: who is
  agreeing, when, and to what, may need its own copy/legal review. The MVP task
  tracker already flags family voice tier for "legal review §7 before public" —
  this flow adds a new consent shape to that review, not just a new capture
  channel.
- **Browser audio format compatibility.** The pipeline assumes AAC-LC `.m4a`
  (labeled `audio/mp4` when sent to ElevenLabs). Browser `MediaRecorder` typically
  produces WebM/Opus (Chrome, Firefox) rather than `.m4a`. Does the web page
  transcode client-side, does the backend accept and relabel other formats, or has
  ElevenLabs' tolerance for other input formats been confirmed? Unresolved.
- **Mic permission failures.** What does the page show if the recipient's browser
  denies or lacks mic access (older browser, locked-down device, no mic at all)?
  Is there a fallback (e.g. upload an existing recording instead)?
- **Moderation/review step.** Does anything review a web-submitted sample before
  it's sent to ElevenLabs — automated (e.g. basic audio-quality/duration checks) or
  human? Today's in-app flow has none; should the web flow, given it accepts audio
  from someone outside the account?
- **Notification back to the parent.** Does the parent get any signal that the
  recipient opened the link / submitted samples / the link expired unused, or do
  they only find out via the existing `VoiceReadyScreen` polling?
- **Rate limiting / abuse.** What stops someone from generating many invite links
  or replaying a captured link to spam the cloning pipeline?

## Out of scope for this doc

- Actual implementation of the web page, invite-link backend, or auth bridge.
- Choice of web framework, hosting provider, or CDN.
- Billing/hosting cost decisions for the new web surface.
- SMS/email delivery mechanics (assume the parent shares the link manually, unless
  a future doc decides otherwise).
- Any redesign of the in-app Family Voices screens beyond adding the "invite"
  entry point.

## Critical files for implementation

- `app/lib/services/voice_repository.dart` — the callable contract (`createVoiceConsent`, `submitVoiceClone`) a web flow must satisfy or bridge into.
- `functions/src/index.ts` — `createVoiceConsent`, `submitVoiceClone`, `processVoiceClone`, `requireTrusted` (the auth/App Check gate that a no-install web recipient can't satisfy as-is).
- `storage.rules` and `firestore.rules` — the exact authorization boundary (`request.auth.uid == uid`) that any invite-token mechanism has to work around or extend.
- `app/lib/ui/family_voices_screens.dart` — where an "Invite someone to record" entry point would live alongside "Record now" / "Upload a clip".
- `docs/storytime-mvp-tasks.md` — existing tracker line (`Add-a-voice invite (s4) — MISSING`) and the "Frozen contract" Family Voice section this spec must not diverge from.
