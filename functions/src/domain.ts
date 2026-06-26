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
