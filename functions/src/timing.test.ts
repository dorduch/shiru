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
});
