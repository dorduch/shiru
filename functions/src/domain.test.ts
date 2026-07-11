import {describe, expect, it} from "vitest";
import {
  contentTypeForSamplePath,
  extensionForMimeType,
  hashInviteToken,
  isInviteExpired,
  isValidInviteToken,
  parseFamilyVoiceId,
  safetyPassed,
  utcQuotaDay,
  validateCreateInviteRequest,
  validateStoryRequest,
  wordCountFor,
} from "./domain";

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

describe("hashInviteToken", () => {
  it("is deterministic for the same input", () => {
    expect(hashInviteToken("some-token")).toBe(hashInviteToken("some-token"));
  });

  it("matches the known sha256 answer for a fixed input", () => {
    expect(hashInviteToken("abc"))
      .toBe("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  });

  it("produces different hashes for different inputs", () => {
    expect(hashInviteToken("token-a")).not.toBe(hashInviteToken("token-b"));
  });

  it("returns 64 lowercase hex chars", () => {
    expect(hashInviteToken("whatever")).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe("isInviteExpired", () => {
  it("is false when now is before expiry", () => {
    expect(isInviteExpired(1000, 999)).toBe(false);
  });

  it("is true when now equals expiry", () => {
    expect(isInviteExpired(1000, 1000)).toBe(true);
  });

  it("is true when now is after expiry", () => {
    expect(isInviteExpired(1000, 1001)).toBe(true);
  });
});

describe("contentTypeForSamplePath", () => {
  it("maps .m4a to audio/mp4", () => {
    expect(contentTypeForSamplePath("sample.m4a")).toEqual({contentType: "audio/mp4", ext: "m4a"});
  });

  it("maps .mp4 to audio/mp4", () => {
    expect(contentTypeForSamplePath("sample.mp4")).toEqual({contentType: "audio/mp4", ext: "m4a"});
  });

  it("maps .webm to audio/webm", () => {
    expect(contentTypeForSamplePath("sample.webm")).toEqual({contentType: "audio/webm", ext: "webm"});
  });

  it("handles uppercase extensions", () => {
    expect(contentTypeForSamplePath("sample.M4A")).toEqual({contentType: "audio/mp4", ext: "m4a"});
    expect(contentTypeForSamplePath("sample.WEBM")).toEqual({contentType: "audio/webm", ext: "webm"});
  });

  it("throws on an unrecognized extension", () => {
    expect(() => contentTypeForSamplePath("sample.wav")).toThrow();
  });

  it("handles a full storage path, not just a bare extension", () => {
    expect(contentTypeForSamplePath("voice-samples/uid/vid/0.webm"))
      .toEqual({contentType: "audio/webm", ext: "webm"});
  });
});

describe("isValidInviteToken", () => {
  it("accepts a valid 43-char base64url token", () => {
    expect(isValidInviteToken("a".repeat(43))).toBe(true);
  });

  it("rejects an empty string", () => {
    expect(isValidInviteToken("")).toBe(false);
  });

  it("rejects a token containing whitespace", () => {
    expect(isValidInviteToken("a".repeat(20) + " " + "b".repeat(20))).toBe(false);
  });

  it("rejects too-short and too-long tokens", () => {
    expect(isValidInviteToken("a".repeat(19))).toBe(false);
    expect(isValidInviteToken("a".repeat(201))).toBe(false);
  });

  it("rejects non-string values", () => {
    expect(isValidInviteToken(12345)).toBe(false);
    expect(isValidInviteToken(null)).toBe(false);
    expect(isValidInviteToken(undefined)).toBe(false);
  });
});

describe("extensionForMimeType", () => {
  it("maps audio/webm to webm", () => {
    expect(extensionForMimeType("audio/webm")).toBe("webm");
  });

  it("maps audio/mp4 and audio/aac to m4a", () => {
    expect(extensionForMimeType("audio/mp4")).toBe("m4a");
    expect(extensionForMimeType("audio/aac")).toBe("m4a");
  });

  it("throws on an unsupported mime type", () => {
    expect(() => extensionForMimeType("audio/wav")).toThrow();
    expect(() => extensionForMimeType("video/mp4")).toThrow();
    expect(() => extensionForMimeType("")).toThrow();
  });
});

describe("validateCreateInviteRequest", () => {
  it("accepts a valid voiceId", () => {
    expect(validateCreateInviteRequest({voiceId: "abc123"})).toEqual({voiceId: "abc123"});
  });

  it("rejects a missing voiceId", () => {
    expect(validateCreateInviteRequest({})).toBeNull();
  });

  it("rejects an empty voiceId", () => {
    expect(validateCreateInviteRequest({voiceId: ""})).toBeNull();
  });

  it("rejects a voiceId with illegal characters", () => {
    expect(validateCreateInviteRequest({voiceId: "a/b"})).toBeNull();
  });

  it("rejects non-object input", () => {
    expect(validateCreateInviteRequest(null)).toBeNull();
    expect(validateCreateInviteRequest("abc123")).toBeNull();
    expect(validateCreateInviteRequest(42)).toBeNull();
  });
});
