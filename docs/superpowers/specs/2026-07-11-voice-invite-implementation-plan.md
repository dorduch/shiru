# Voice Invite Flow — Implementation Plan

Date: 2026-07-11
Status: approved — implementation in progress
Companion to: `2026-07-11-voice-invite-flow.md` (the product spec)

Auth bridge decided: **server-minted custom Firebase Auth token scoped to the invite.**

## Two architecture corrections (found during scoping)

**(a) The web session cannot call `submitVoiceClone` directly.** It is `onCall({enforceAppCheck: true})` and its first line is `requireTrusted(request)`, which throws without an App Check token. A browser signed in via custom token has `request.auth` but no App Check token, so Firebase rejects it at the platform gate. App Check cannot be conditionally skipped inside a callable. **Fix:** extract `submitVoiceClone`'s core logic into a shared helper `flipVoiceToQueued`. `submitVoiceClone` stays a thin wrapper for the in-app path (calls the helper after `requireTrusted`). A new `submitVoiceInvite` (invite-claim gated, no App Check) calls the same helper for the web path. `processVoiceClone` (the Firestore trigger) is the genuine, unmodified reuse point.

**(b) `processVoiceClone` content-type bug.** `index.ts` hardcodes `new Blob([...], {type: "audio/mp4"})` regardless of the stored file. Browser recordings are webm/opus (Chrome/Firefox) or mp4/aac (Safari); webm would be mislabeled. **Fix:** derive content-type from file extension via a pure helper. Backward compatible — existing `.m4a` maps to the same `audio/mp4`. **UNVERIFIED assumption:** that ElevenLabs `/v1/voices/add` accepts `audio/webm` — must be smoke-tested live before shipping.

## Pinned contracts (fix before any parallel task)

### Firestore: `voiceInvites/{tokenHash}` (top-level, Admin-SDK-only)
```ts
{
  parentUid: string;
  voiceId: string;
  status: "pending" | "redeemed" | "expired" | "canceled";
  createdAt: Timestamp;
  expiresAt: Timestamp;                 // createdAt + 7 days
  redeemedAt: Timestamp | null;
  redeemedSyntheticUid: string | null;
}
```
- Doc ID = `sha256(token)` hex (64 chars). Raw token never persisted.
- `firestore.rules`: `match /voiceInvites/{tokenHash} { allow read, write: if false; }`
- Composite index (`parentUid`, `voiceId`, `status`) in `firestore.indexes.json` for the supersede query.

### `createVoiceInvite` (callable, enforceAppCheck: true, parent path)
```
Request:  { voiceId: string }
Response: { url: string; expiresAt: string /* ISO */ }
```
Preconditions: `requireTrusted`; voice `status ∈ {consented, failed}`; `isFamilyVoiceEnabled()`; daily invite-creation quota (~5/day). On success: `token = base64url(crypto.randomBytes(32))` (256-bit), write invite doc, cancel any other `pending` invite for the same `voiceId`, return `https://<INVITE_HOST>/invite/{token}`.

### `redeemVoiceInvite` (callable, enforceAppCheck: false, no prior auth)
```
Request:  { token: string }
Response: { customToken: string; name: string; relationship: string;
            prompts: {label: string; text: string}[]; expiresAt: string }
```
- Transaction on `voiceInvites/{sha256(token)}`; not-found / wrong-status / expired all throw the SAME generic `HttpsError("failed-precondition", "This invite link is no longer valid.")`.
- Flip `pending → redeemed`, set `redeemedAt`.
- Synthetic uid: `invite:${tokenHash.slice(0,32)}`.
- Custom claims (PINNED): `{ invite: true, parentUid, voiceId }`.
- Response NEVER includes `parentUid` / `voiceId` — downstream re-derives from verified claims.
- Prompts: the same 5 guided-capture prompts (single source of truth server-side).

### `submitVoiceInvite` (callable, enforceAppCheck: false, invite-claim gated)
```
Request:  {}   // uid/voiceId read from request.auth.token, never client-supplied
Response: { ok: true }
```
Guard: `request.auth?.token.invite === true` (else `unauthenticated`); re-read invite doc from claims, require `status === "redeemed"` AND `redeemedAt` within a 2-hour window. Calls `flipVoiceToQueued(db, parentUid, voiceId, samplePaths)`.

### Sample upload — proxy through a callable (default)
`uploadVoiceInviteSample` (same claim-gate), receives each sample as base64, writes via Admin SDK to `voice-samples/{parentUid}/{voiceId}/{idx}.{ext}`, `idx ∈ [0,4]`, `ext` from MIME. Rejects payloads decoding to >8MB. **Zero `storage.rules` changes** with this design; avoids the unverifiable question of whether Storage App Check enforcement is on.
- Override option (direct client→Storage writes) requires this rule and confirming Storage App Check is off:
  `allow write: if (request.auth.uid == uid) || (request.auth.token.invite == true && request.auth.token.parentUid == uid && request.auth.token.voiceId == voiceId && request.resource.size < 15*1024*1024);`

### `contentTypeForSamplePath(path)` pure helper (§(b) fix)
`.m4a/.mp4 -> audio/mp4`; `.webm -> audio/webm`; else throw. Used per-sample in `processVoiceClone`.

## Open questions — decided defaults (vetoable)

| Question | Decision |
|---|---|
| Web stack/hosting | Static vanilla JS/HTML on Firebase Hosting (net-new; no hosting config today). Firebase JS SDK v9 modular via CDN. No framework, no build step. Rewrite `/invite/**` → `/invite/index.html`. |
| Upload mechanism | Proxy through callable (Admin SDK write). No `storage.rules` change. |
| Link lifetime | 7 days, single redemption. Resend = new token, cancels old pending. |
| Browser audio format | Accept webm + mp4 as-is, no transcode. Fix content-type derivation. Live webm smoke test required. |
| Consent | In-app parent consent stays the gate; web page adds recipient checkbox. Legal review still required before public. |
| Rate limiting | ~5 invites/day/user; one active pending invite per voice; server-side sample size cap. |
| Parent notification | Existing in-app `VoiceReadyScreen` polling only. No push/email/SMS. |

## Task waves

**Wave 1 (parallel, no deps):**
- Task 1 [BE, S] — `domain.ts` pure helpers: `hashInviteToken`, `isInviteExpired`, `contentTypeForSamplePath`, arg validators. + `domain.test.ts` vitest.
- Task 6 [RULES/INFRA, S] — `firebase.json` hosting block, `public/invite/index.html` skeleton, `firestore.rules` `voiceInvites` block, `firestore.indexes.json` composite index.

**Wave 2 (sequential, same file `index.ts`):**
- Task 2 [BE, M] — extract `flipVoiceToQueued`; `submitVoiceClone` becomes thin wrapper. Existing 8 vitest tests must still pass.
- Task 5 [BE, S] — `processVoiceClone` content-type fix via Task 1 helper. Extend `elevenlabs_mock.cjs` + webm fixture. Live smoke test via `real_clone_demo.mjs`.

**Wave 3 (parallel, deps: Wave 1):**
- Task 3 [BE, M] — `createVoiceInvite` callable.
- Task 8 [FE, M] — "Invite someone to record" row + `VoiceInviteShareScreen` + `voice_repository.createInvite` + router route. Can start immediately against pinned §createVoiceInvite shape.

**Wave 4 (deps: Wave 2):**
- Task 4 [BE, L] — `redeemVoiceInvite` + `submitVoiceInvite` + `uploadVoiceInviteSample`. The crux; one reviewed unit.
- Task 7 [WEB, L] — static invite page (record via MediaRecorder, file-upload fallback, consent checkbox, submit state machine). Can start against pinned contracts, mocking responses.

**Wave 5:**
- Task 9 [QA, M] — emulator e2e + one live device/browser pass. Negative paths: expired, replayed, forged claims, oversized sample.
- Task 10 [DOCS, S] — update `docs/storytime-mvp-tasks.md` s4 line + mark spec open-questions decided.

## Security checklist
- 256-bit token, base64url; only `sha256(token)` persisted (as doc ID).
- Replay closed by transactional `pending → redeemed` flip.
- Expiry checked at redeem AND re-checked at submit/upload via bounded `redeemedAt` window.
- Downstream reads `parentUid`/`voiceId` from verified claims only, never client fields.
- Leaked link: opaque token only; post-redeem identity scoped by claims to one `{parentUid, voiceId}`, can only call submit/upload, no reads.
- Existing `request.auth.uid == uid` boundary untouched (proxy-upload design).
