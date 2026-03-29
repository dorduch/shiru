# Onboarding Experience — Design Spec
**Date:** 2026-03-29
**App:** Shiru (Flutter, local-first kids audio player)
**Status:** Ready for implementation planning

---

## Goal

Design a first-run onboarding flow that does three things quickly:

1. Helps a parent understand what Shiru is and how to get to a playable first card fast.
2. Builds trust with plain language about privacy and safety.
3. Separates the default local-only product story from the optional AI voice workflow.

The onboarding should feel calm, parent-first, and short. It should never read like a growth funnel or a subscription wall.

---

## Core Messages

These messages should be repeated consistently across onboarding, settings, and voice flows.

### 1. Local-first promise

Primary copy:

> Everything stays on this device by default.

Support copy:

> Your library, recordings, categories, and playback stay on this tablet.

### 2. Voice exception

Primary copy:

> The only exception is optional family voice generation.

Support copy:

> If you choose a family voice for AI story narration, that voice sample may be sent to our voice providers to generate audio. Any temporary cloud voice created for that step is deleted afterward.

Important implementation note:
- This wording is intentionally precise.
- Cartesia clip mode does not create a stored cloud voice.
- ElevenLabs uses an ephemeral clone flow, then deletes the temporary voice.
- Do not claim that "voices never leave the device."
- Do not imply that all providers store a reusable cloud voice.

### 3. Child safety / ads promise

Primary copy:

> We will never show ads to your children.

Support copy:

> No banner ads, no autoplay promotions, no manipulative reward loops in kid mode.

---

## Product Principles

- Show trust information before asking for setup work.
- Keep the shared first-run experience parent-readable, not kid-targeted.
- Keep the kid home surface visually quiet and free of onboarding clutter after setup.
- Show the high-level voice exception in onboarding, but reserve detailed consent for the voice-specific flow.
- Avoid presenting premium features as part of the core onboarding success path.

---

## Proposed First-Run Flow

### Screen 1: Welcome

**Audience:** Shared, but written for the parent

**Purpose:** Explain the product in one sentence and start parent setup.

**Content**
- Title: `A calm audio player for kids`
- Body: `Add your own stories, songs, and recordings, then let your child press play without ads or endless scrolling.`
- Primary CTA: `Set Up With Parent`
- Secondary CTA: `See How It Works`

**Notes**
- Do not drop directly into the library or PIN screen on fresh install.
- This screen should feel warm and product-defining, not security-heavy.

### Screen 2: Privacy & Safety Promise

**Audience:** Parent

**Purpose:** Establish trust before permissions or PIN setup.

**Layout**
- Three stacked promise cards with icons.

**Card 1**
- Title: `On this device`
- Body: `Your library, recordings, categories, and playback stay on this tablet.`

**Card 2**
- Title: `Voices are the exception`
- Body: `If you use optional family voice narration, that sample may be sent to our voice providers to create the audio. Any temporary cloud voice created for that step is deleted afterward.`

**Card 3**
- Title: `No ads for kids`
- Body: `We will never show ads to your children. Kid mode stays focused on listening, not promotion.`

**CTA**
- Primary: `Continue`

**Notes**
- This is the most important onboarding screen.
- Language should be plain, not legalistic.
- Add a secondary text link to `Learn more` only if a settings/help destination exists.

### Screen 3: Parent Access Setup

**Audience:** Parent

**Purpose:** Establish that setup tools are adult-only.

**Flow**
- Reuse the current age gate and PIN patterns.
- Replace the feeling of "blocked access" with "set up parent access."

**Recommended sequence**
1. Age check intro copy
2. Create or confirm parent PIN

**Copy adjustment**
- Title: `Parent setup`
- Body: `Library tools, voice tools, and settings are for adults only.`

**Notes**
- On first run, the PIN should be created, not silently default to `1234`.
- After onboarding, the normal parent gate flow can remain strict and minimal.

### Screen 4: Choose Your First Setup Path

**Audience:** Parent

**Purpose:** Shorten time to first successful playback.

**Options**
- `Add One Story`
  - Subtitle: `Record or import a single card in a minute or two.`
- `Import A Bunch`
  - Subtitle: `Bring in multiple files and build the library faster.`
- `Explore First`
  - Subtitle: `Finish setup later and open the kid view now.`

**Notes**
- `Add One Story` should be the recommended path.
- Keep Story Builder and family voices out of this decision screen.
- Those are optional follow-on features, not onboarding blockers.

### Screen 5: Success / Hand-off

**If the parent added content**
- Title: `Ready for kid mode`
- Body: `Your child can tap a card and start listening. Parent tools stay behind the lock.`
- CTA: `Open Kid Mode`

**If the parent skipped content creation**
- Title: `You can add stories anytime`
- Body: `Open the lock icon whenever you want to add cards or manage voices.`
- CTA: `Go To Home`

---

## Voice-Specific Disclosure Strategy

The onboarding promise should stay high level. The detailed disclosure belongs inside the voice path.

### Where detailed voice disclosure should appear

- `VoiceRecordScreen`
- Story Builder provider-selection step
- Any future "use family voice" action before generation starts

### Required detailed copy

Recommended copy:

> Family voice narration is optional. When you use it, your recording and story request may be sent to OpenAI and our voice providers to generate narration. If a temporary cloud voice is created for that process, it is deleted afterward. Use only your own adult voice or a voice you have permission to use.

### Why this split matters

- Onboarding should build trust without overwhelming the parent.
- Voice consent needs to be explicit at the moment of use.
- The generic product should still read as local-first because that is the default behavior.

---

## Empty-State Guidance

The first-run empty library state should continue the onboarding instead of feeling dead.

### Parent library empty state

- Title: `Start your child's library`
- Checklist:
  - `Add a first story`
  - `Import audio from this device`
  - `Optional: add a family voice`
- Trust footer:
  - `Everything stays on this device by default.`
  - `We never show ads to children.`

### Kid home empty state

Current tone is acceptable, but should be more specific:

Recommended copy:

> Ask a parent to add a story to get started.

Avoid mentioning voices or premium features in the kid empty state.

---

## Settings / Persistent Trust Surface

Onboarding should not be the only place these promises exist.

Add a lightweight trust section in parent settings or library:

- `On-device by default`
- `Family voices may use cloud generation`
- `Temporary cloud voices are deleted after use`
- `No ads shown to children`

This gives parents a place to revisit the promises later without re-running onboarding.

---

## UX Notes

- Tone should be calm, plainspoken, and concrete.
- Avoid words like `monetize`, `engagement`, `retention`, or `unlock`.
- Avoid fear-based privacy language.
- Avoid legal over-explanation on the main onboarding path.
- Never place upsell messaging before the trust and setup story.

---

## Success Criteria

- A parent understands the product promise in under 20 seconds.
- A parent understands that the app is local-first.
- A parent understands that family voices are the only cloud exception.
- A parent sees a clear promise that children will not see ads.
- Time to first playable card remains under the current MVP target.
