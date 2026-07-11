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

// Maps each character index of `text` to a start time (seconds). Uses the
// alignment's own character stream directly when it reconstructs `text`
// exactly; otherwise walks both character streams defensively, carrying the
// last known start through any position the API collapsed or expanded.
function charStartTimes(text: string, chars: string[], starts: number[]): number[] {
  if (chars.join("") === text && starts.length === text.length) {
    return starts;
  }
  const out = new Array<number>(text.length).fill(0);
  let ai = 0;
  let last = 0;
  for (let ti = 0; ti < text.length; ti++) {
    if (ai < chars.length && chars[ai] === text[ti]) {
      last = starts[ai] ?? last;
      out[ti] = last;
      ai++;
    } else {
      out[ti] = last;
    }
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
  const startAt = charStartTimes(text, chars, starts);
  return tokenize(text).map((t) => Number((startAt[t.offset] ?? 0).toFixed(3)));
}
