// Derives per-word start times (seconds) for the read-along highlight, from
// an ElevenLabs `/with-timestamps` alignment block. This is the same recipe
// used by `functions/dev/generate_starter_stories.mjs` to produce the bundled
// `.timing.json` assets for curated stories — ported here so AI-generated
// (Composer) stories get real timing instead of a linear-progress guess.
//
// The tokenization rule (`\S+`) MUST stay byte-for-byte identical to the
// Dart `tokenizeStory` in `app/lib/logic/story_tokenizer.dart` and to the dev
// script's `tokenize()`, since the resulting word index has to line up with
// the same word list the Flutter renderer displays.

export type ElevenLabsAlignment = {
  characters?: string[];
  character_start_times_seconds?: number[];
  characterStartTimesSeconds?: number[];
};

type WordToken = {i: number; offset: number};

/** Splits text into \S+ runs, each carrying its character offset into text. */
function tokenize(text: string): WordToken[] {
  const tokens: WordToken[] = [];
  const re = /\S+/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text)) !== null) {
    tokens.push({i: tokens.length, offset: m.index});
  }
  return tokens;
}

const WHITESPACE_RE = /\s/;

// How far to peek ahead on either stream when the two characters at the
// current positions don't match, looking for a resync point.
const LOOKAHEAD = 8;

// Maps each character index of `text` to a start time (seconds). Uses the
// alignment's own character stream directly when it reconstructs `text`
// exactly; otherwise walks both character streams with a two-pointer scan
// that recovers from all three kinds of divergence ElevenLabs alignments can
// introduce:
//   - omission: `text` has a character the alignment stream skipped
//     (`chars` is missing it) — advance `text` alone, carrying the last
//     known start through the gap.
//   - insertion: the alignment stream has an extra character not present in
//     `text` — advance `chars` alone, updating the carried start.
//   - substitution: the two streams render the "same" character
//     differently (an em dash vs. a plain hyphen, curly vs. straight
//     quotes, an ellipsis glyph vs. three dots, spelled-out vs. digit
//     numerals) — neither stream has a nearby resync anchor for the other's
//     character, so both pointers advance together and the alignment's
//     start time is carried through. This is the case the old
//     never-advance-on-mismatch walk got wrong: it froze `ai` forever,
//     plateauing every later word's start time at whatever was last
//     matched.
// Whitespace is skipped freely on either side without consuming the other
// stream, since word-start times only ever key off non-whitespace offsets.
function charStartTimes(text: string, chars: string[], starts: number[]): number[] {
  if (chars.join("") === text && starts.length === text.length) {
    return starts;
  }
  const out = new Array<number>(text.length).fill(0);
  let ti = 0;
  let ai = 0;
  let last = 0;

  while (ti < text.length) {
    if (WHITESPACE_RE.test(text[ti])) {
      out[ti] = last;
      ti++;
      continue;
    }
    while (ai < chars.length && WHITESPACE_RE.test(chars[ai])) {
      last = starts[ai] ?? last;
      ai++;
    }
    if (ai >= chars.length) {
      // Alignment stream exhausted; carry the last known start through the
      // remainder of the text rather than snapping back to 0.
      out[ti] = last;
      ti++;
      continue;
    }
    if (chars[ai] === text[ti]) {
      last = starts[ai] ?? last;
      out[ti] = last;
      ai++;
      ti++;
      continue;
    }

    // Mismatch: look for a resync anchor within a bounded lookahead window
    // on each stream before concluding this is a plain substitution.
    let insertionOffset = -1; // chars[ai + k] === text[ti]: alignment has extra char(s)
    for (let k = 1; k <= LOOKAHEAD && ai + k < chars.length; k++) {
      if (chars[ai + k] === text[ti]) {
        insertionOffset = k;
        break;
      }
    }
    let omissionOffset = -1; // text[ti + k] === chars[ai]: text has extra char(s)
    for (let k = 1; k <= LOOKAHEAD && ti + k < text.length; k++) {
      if (text[ti + k] === chars[ai]) {
        omissionOffset = k;
        break;
      }
    }

    if (insertionOffset !== -1 && (omissionOffset === -1 || insertionOffset <= omissionOffset)) {
      // Skip the alignment's extra character(s), carrying their starts.
      for (let k = 0; k < insertionOffset; k++) {
        last = starts[ai] ?? last;
        ai++;
      }
      continue;
    }
    if (omissionOffset !== -1) {
      // Skip the text's extra character(s); the alignment has nothing for
      // them, so they inherit the last known start.
      for (let k = 0; k < omissionOffset; k++) {
        out[ti] = last;
        ti++;
      }
      continue;
    }

    // No resync anchor nearby: treat as a one-for-one substitution so both
    // pointers keep advancing together instead of desyncing permanently.
    last = starts[ai] ?? last;
    out[ti] = last;
    ai++;
    ti++;
  }
  return out;
}

/**
 * Derives one ascending start-time-in-seconds per word of `text`, from an
 * ElevenLabs `/with-timestamps` alignment block.
 *
 * Returns `[]` (never throws) when `text` is empty or the alignment has no
 * usable character data at all — callers should treat that as "no timing
 * available" and let the client fall back to its linear-progress estimate,
 * rather than failing story generation over it.
 */
export function deriveWordStarts(text: string, alignment: ElevenLabsAlignment | undefined | null): number[] {
  if (!text) return [];
  const chars = alignment?.characters ?? [];
  const starts = alignment?.character_start_times_seconds ?? alignment?.characterStartTimesSeconds ?? [];
  if (chars.length === 0 || starts.length === 0) return [];
  const words = tokenize(text);
  const startAt = charStartTimes(text, chars, starts);
  const result = words.map((t) => Number((startAt[t.offset] ?? 0).toFixed(3)));

  // Sanity gate: the walk above is defensive but not infallible against
  // pathological alignments. If it didn't produce exactly one non-decreasing,
  // finite, non-negative start per `\S+` word of `text`, don't hand the
  // caller a malformed or plateaued timing array — a clean `[]` lets the
  // client fall back to its linear-progress estimate, which beats frozen
  // or out-of-order highlighting.
  if (result.length !== words.length) return [];
  for (let i = 0; i < result.length; i++) {
    const v = result[i];
    if (!Number.isFinite(v) || v < 0) return [];
    if (i > 0 && v < result[i - 1]) return [];
  }
  return result;
}
