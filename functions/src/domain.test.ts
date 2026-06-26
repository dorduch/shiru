import {describe, expect, it} from "vitest";
import {parseFamilyVoiceId, safetyPassed, utcQuotaDay, validateStoryRequest, wordCountFor} from "./domain";

const valid = {
  character: "princess", scene: "forest", theme: "kindness",
  plot: "surpriseFriend", narratorKey: "fairyFern", ageBand: "early",
  idempotencyKey: "12345678",
};

describe("story domain", () => {
  it("accepts only allowlisted story requests", () => {
    expect(validateStoryRequest(valid)).toEqual(valid);
    expect(validateStoryRequest({...valid, theme: "horror"})).toBeNull();
  });

  it("maps age bands to increasing word counts", () => {
    expect(wordCountFor("early")).toBe(350);
    expect(wordCountFor("older")).toBe(800);
  });

  it("uses a UTC quota day", () => {
    expect(utcQuotaDay(new Date("2026-06-23T23:59:59Z"))).toBe("2026-06-23");
  });

  it("fails closed on malformed safety results", () => {
    expect(safetyPassed({safe: true, concerns: []})).toBe(true);
    expect(safetyPassed({safe: true})).toBe(false);
    expect(safetyPassed({safe: false, concerns: []})).toBe(false);
  });
});

describe("family voice narrator", () => {
  it("accepts valid family narrator keys in validateStoryRequest", () => {
    expect(validateStoryRequest({...valid, narratorKey: "family:abc123"})).not.toBeNull();
    expect(validateStoryRequest({...valid, narratorKey: "family:voice-abc_XYZ"})).not.toBeNull();
  });

  it("rejects malformed family narrator keys", () => {
    expect(validateStoryRequest({...valid, narratorKey: "family:"})).toBeNull();
    expect(validateStoryRequest({...valid, narratorKey: "family: spaces"})).toBeNull();
    expect(validateStoryRequest({...valid, narratorKey: "FAMILY:abc"})).toBeNull();
    expect(validateStoryRequest({...valid, narratorKey: "family:" + "x".repeat(129)})).toBeNull();
  });

  it("still accepts built-in narrator keys", () => {
    expect(validateStoryRequest({...valid, narratorKey: "wizardWally"})).not.toBeNull();
    expect(validateStoryRequest({...valid, narratorKey: "roboRay"})).not.toBeNull();
    expect(validateStoryRequest({...valid, narratorKey: "fairyFern"})).not.toBeNull();
  });

  it("parseFamilyVoiceId extracts id from valid key and returns null for others", () => {
    expect(parseFamilyVoiceId("family:abc123")).toBe("abc123");
    expect(parseFamilyVoiceId("family:voice-id_X")).toBe("voice-id_X");
    expect(parseFamilyVoiceId("fairyFern")).toBeNull();
    expect(parseFamilyVoiceId("family:")).toBeNull();
    expect(parseFamilyVoiceId("family:has spaces")).toBeNull();
    expect(parseFamilyVoiceId(42)).toBeNull();
  });
});
