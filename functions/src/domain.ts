import {createHash} from "node:crypto";

export const characters = [
  "prince", "princess", "doctor", "builder", "firefighter", "animalFriend",
] as const;
export const scenes = [
  "castle", "space", "underTheSea", "forest", "city", "farm",
] as const;
export const themes = [
  "friendship", "bravery", "bedtime", "adventure", "mystery", "kindness",
] as const;
export const plots = [
  "somethingGoesWrong", "surpriseFriend", "treasureHunt",
  "problemToSolve", "bigWin", "magicMoment",
] as const;
export const narrators = ["wizardWally", "fairyFern", "roboRay"] as const;
export const ageBands = ["early", "middle", "older"] as const;

export type StoryRequest = {
  character: typeof characters[number];
  scene: typeof scenes[number];
  theme: typeof themes[number];
  plot: typeof plots[number];
  narratorKey: typeof narrators[number] | string;
  ageBand: typeof ageBands[number];
  idempotencyKey: string;
};

function isChoice<T extends string>(value: unknown, choices: readonly T[]): value is T {
  return typeof value === "string" && choices.includes(value as T);
}

/** Returns the voiceId if narratorKey is a valid family voice key, else null. */
export function parseFamilyVoiceId(narratorKey: unknown): string | null {
  if (typeof narratorKey !== "string") return null;
  const match = narratorKey.match(/^family:([A-Za-z0-9_\-]{1,128})$/);
  return match ? match[1] : null;
}

export function validateStoryRequest(data: unknown): StoryRequest | null {
  if (!data || typeof data !== "object") return null;
  const value = data as Record<string, unknown>;
  const narratorKey = value.narratorKey;
  const narratorValid = isChoice(narratorKey, narrators) || parseFamilyVoiceId(narratorKey) !== null;
  if (!isChoice(value.character, characters) ||
      !isChoice(value.scene, scenes) ||
      !isChoice(value.theme, themes) ||
      !isChoice(value.plot, plots) ||
      !narratorValid ||
      !isChoice(value.ageBand, ageBands) ||
      typeof value.idempotencyKey !== "string" ||
      value.idempotencyKey.length < 8 || value.idempotencyKey.length > 128) {
    return null;
  }
  return value as StoryRequest;
}

export function utcQuotaDay(date = new Date()): string {
  return date.toISOString().slice(0, 10);
}

export function wordCountFor(ageBand: StoryRequest["ageBand"]): number {
  return {early: 350, middle: 550, older: 800}[ageBand as typeof ageBands[number]] ?? 550;
}

export function safetyPassed(value: unknown): boolean {
  if (!value || typeof value !== "object") return false;
  const result = value as Record<string, unknown>;
  return result.safe === true && Array.isArray(result.concerns) && result.concerns.length === 0;
}

/** Lowercase hex sha256 of the raw invite token. Only this hash is ever persisted. */
export function hashInviteToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

/** Pure expiry check — caller injects `nowMillis` (mirrors utcQuotaDay's injectable date) for testability. */
export function isInviteExpired(expiresAtMillis: number, nowMillis: number): boolean {
  return nowMillis >= expiresAtMillis;
}

/**
 * Derives the Storage content-type + normalized extension from a voice sample's file path.
 * `.m4a`/`.mp4` both normalize to ext "m4a" (matching the existing in-app filename convention
 * and preserving the byte-identical "audio/mp4" content-type processVoiceClone already hardcodes),
 * while `.webm` keeps its own ext so browser-recorded samples round-trip correctly.
 */
export function contentTypeForSamplePath(path: string): {contentType: string; ext: string} {
  const match = path.match(/\.([A-Za-z0-9]+)$/);
  const extension = match ? match[1].toLowerCase() : "";
  if (extension === "m4a" || extension === "mp4") {
    return {contentType: "audio/mp4", ext: "m4a"};
  }
  if (extension === "webm") {
    return {contentType: "audio/webm", ext: "webm"};
  }
  throw new Error(`contentTypeForSamplePath: unrecognized sample extension in path "${path}"`);
}

/** Non-empty string, tolerant length bounds around a base64url 32-byte token (43 chars), no whitespace. */
export function isValidInviteToken(value: unknown): value is string {
  return typeof value === "string" &&
    value.length >= 20 && value.length <= 200 &&
    !/\s/.test(value);
}

/** Argument-shape validator for createVoiceInvite, mirroring validateStoryRequest's return-null-on-invalid style. */
export function validateCreateInviteRequest(data: unknown): {voiceId: string} | null {
  if (!data || typeof data !== "object") return null;
  const value = data as Record<string, unknown>;
  if (typeof value.voiceId !== "string" || !/^[A-Za-z0-9_\-]{1,128}$/.test(value.voiceId)) {
    return null;
  }
  return {voiceId: value.voiceId};
}

/**
 * Maps an `uploadVoiceInviteSample` MIME type to the Storage file extension.
 * Restricted to exactly the formats `contentTypeForSamplePath` accepts, so a
 * sample recorded via the web invite flow round-trips through
 * `processVoiceClone` the same way in-app samples do. Throws on anything else.
 */
export function extensionForMimeType(mimeType: string): string {
  if (mimeType === "audio/webm") return "webm";
  if (mimeType === "audio/mp4" || mimeType === "audio/aac") return "m4a";
  throw new Error(`extensionForMimeType: unsupported mime type "${mimeType}"`);
}
