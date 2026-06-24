import {describe, expect, it} from "vitest";
import {safetyPassed, utcQuotaDay, validateStoryRequest, wordCountFor} from "./domain";

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
