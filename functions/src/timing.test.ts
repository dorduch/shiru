import {describe, expect, it} from "vitest";
import {deriveWordStarts} from "./timing";

describe("deriveWordStarts", () => {
  it("derives one ascending start time per word from an exact alignment", () => {
    const text = "Once upon a time";
    // "Once upon a time" -> characters, one start time per character.
    const characters = text.split("");
    const character_start_times_seconds = [
      0.0, 0.1, 0.2, 0.3, // "Once"
      0.4, // " "
      0.5, 0.6, 0.7, 0.8, // "upon"
      0.9, // " "
      1.0, // "a"
      1.1, // " "
      1.2, 1.3, 1.4, 1.5, // "time"
    ];
    const words = deriveWordStarts(text, {characters, character_start_times_seconds});
    expect(words).toEqual([0.0, 0.5, 1.0, 1.2]);
  });

  it("accepts the camelCase key variant for start times", () => {
    const text = "Hi there";
    const characters = text.split("");
    const characterStartTimesSeconds = [0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35];
    const words = deriveWordStarts(text, {characters, characterStartTimesSeconds});
    // "Hi" starts at offset 0 -> 0.0; "there" starts at offset 3 ('t') -> 0.15.
    expect(words).toEqual([0.0, 0.15]);
  });

  it("falls back to a defensive walk when characters do not reconstruct the input text", () => {
    // The alignment collapsed the double space between "a" and "gap" into a
    // single character, so `characters.join("")` no longer equals `text`
    // exactly and the fast path can't be used.
    const text = "a  gap";
    const characters = ["a", " ", "g", "a", "p"];
    const character_start_times_seconds = [0.0, 0.1, 0.5, 0.6, 0.7];
    const words = deriveWordStarts(text, {characters, character_start_times_seconds});
    // "a" starts at 0.0 (from the matching first char); "gap" starts at the
    // offset of its first character 'g', which the walk carries forward from
    // the last matched start once the streams re-sync.
    expect(words).toEqual([0.0, 0.5]);
  });

  it("returns an empty array when there is no usable alignment data", () => {
    expect(deriveWordStarts("some text", undefined)).toEqual([]);
    expect(deriveWordStarts("some text", null)).toEqual([]);
    expect(deriveWordStarts("some text", {})).toEqual([]);
    expect(deriveWordStarts("some text", {characters: [], character_start_times_seconds: []})).toEqual([]);
  });

  it("returns an empty array for empty text", () => {
    expect(deriveWordStarts("", {characters: [], character_start_times_seconds: []})).toEqual([]);
  });

  it("recovers from a mid-text em-dash substitution instead of plateauing later words (regression)", () => {
    // "The wizard waited—then flew away" — the alignment renders the em dash
    // as a plain hyphen, a one-for-one substitution that doesn't shift any
    // later character offsets. Before the fix, the old walk never advanced
    // its alignment pointer past a mismatch, so every word after "waited—then"
    // would freeze at the em dash's start time (1.7) instead of continuing
    // to climb. The fixed walk resyncs immediately and "flew"/"away" get
    // their own correctly-advancing starts.
    const text = "The wizard waited—then flew away";
    const characters = [...text.slice(0, 17), "-", ...text.slice(18)];
    const character_start_times_seconds = characters.map((_, i) => Number((i * 0.1).toFixed(3)));
    const words = deriveWordStarts(text, {characters, character_start_times_seconds});
    // Offsets: "The"=0, "wizard"=4, "waited—then"=11, "flew"=23, "away"=28.
    expect(words).toEqual([0, 0.4, 1.1, 2.3, 2.8]);
  });

  it("recovers from curly-quote and ellipsis substitutions in the same walk", () => {
    // `text` has an LLM-typical curly-quoted, ellipsis-bearing phrase; the
    // alignment renders it with straight quotes and an expanded "..." (a
    // substitution for the quotes, plus an insertion of two extra
    // alignment-only characters for the expanded ellipsis).
    const text = "She said “wait…” softly";
    const characters = [
      ..."She said ",
      "\"", "w", "a", "i", "t", ".", ".", ".", "\"",
      ..." softly",
    ];
    const character_start_times_seconds = characters.map((_, i) => Number((i * 0.1).toFixed(3)));
    const words = deriveWordStarts(text, {characters, character_start_times_seconds});
    // Offsets: "She"=0, "said"=4, the quoted phrase=9, "softly"=17.
    expect(words).toEqual([0, 0.4, 0.9, 1.9]);
  });

  it("recovers from an omission (alignment missing a character present in text)", () => {
    // The alignment drops the "d" in "wonderful" entirely.
    const text = "Hello wonderful world";
    const all = [...text];
    const dIndex = text.indexOf("wonderful") + 3; // the "d" in "wonderful"
    expect(all[dIndex]).toBe("d");
    const characters = [...all.slice(0, dIndex), ...all.slice(dIndex + 1)];
    const character_start_times_seconds = characters.map((_, i) => Number((i * 0.1).toFixed(3)));
    const words = deriveWordStarts(text, {characters, character_start_times_seconds});
    // Offsets: "Hello"=0, "wonderful"=6, "world"=16.
    expect(words).toEqual([0, 0.6, 1.5]);
  });

  it("recovers from an insertion (alignment has an extra character not in text)", () => {
    // The alignment stutters and doubles the "r" in "wonderful".
    const text = "Hello wonderful world";
    const all = [...text];
    const rIndex = text.indexOf("wonderful") + 5; // the "r" in "wonderful"
    expect(all[rIndex]).toBe("r");
    const characters = [...all.slice(0, rIndex), "r", ...all.slice(rIndex)];
    const character_start_times_seconds = characters.map((_, i) => Number((i * 0.1).toFixed(3)));
    const words = deriveWordStarts(text, {characters, character_start_times_seconds});
    // Offsets: "Hello"=0, "wonderful"=6, "world"=16.
    expect(words).toEqual([0, 0.6, 1.7]);
  });

  it("returns an empty array when the derived starts are not non-decreasing", () => {
    const text = "Hello world";
    const characters = [...text];
    // Fast path applies (characters reconstruct text exactly), but the
    // start-time data itself is corrupt: "world" starts earlier than "Hello".
    const character_start_times_seconds = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5];
    expect(deriveWordStarts(text, {characters, character_start_times_seconds})).toEqual([]);
  });

  it("returns an empty array when a derived start is negative", () => {
    const text = "Hello world";
    const characters = [...text];
    const character_start_times_seconds = [0, 0.1, 0.2, 0.3, 0.4, 0.5, -1, 0.7, 0.8, 0.9, 1.0];
    expect(deriveWordStarts(text, {characters, character_start_times_seconds})).toEqual([]);
  });
});
