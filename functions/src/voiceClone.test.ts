import {describe, expect, it} from "vitest";
import type {Firestore} from "firebase-admin/firestore";
import {flipVoiceToQueued} from "./voiceClone";

type FakeDocData = Record<string, unknown> | undefined;

function fakeDocRef(data: FakeDocData, onUpdate: (update: Record<string, unknown>) => void) {
  return {
    get: async () => ({
      exists: data !== undefined,
      data: () => data,
    }),
    update: async (update: Record<string, unknown>) => {
      onUpdate(update);
    },
  };
}

/**
 * Minimal hand-rolled fake of the only two Firestore surfaces
 * `flipVoiceToQueued` touches: `db.doc(path).get()` and `db.doc(path).update(...)`.
 * `docs` maps a path to the data its `.get()` should return (a missing key
 * means "not found"). Every `.update()` call across any path is recorded in
 * `updates` so tests can assert both that a write happened and that it
 * happened (or didn't) on the expected doc.
 */
function fakeDb(docs: Record<string, FakeDocData>) {
  const updates: {path: string; data: Record<string, unknown>}[] = [];
  const db = {
    doc: (path: string) => fakeDocRef(docs[path], (data) => updates.push({path, data})),
  };
  return {db: db as unknown as Firestore, updates};
}

const uid = "user1";
const voiceId = "voice1";
const voicePath = `users/${uid}/voices/${voiceId}`;
const samplePaths = [`voice-samples/${uid}/${voiceId}/0.m4a`];

describe("flipVoiceToQueued", () => {
  it("flips a consented voice to queued with the given sample paths", async () => {
    const {db, updates} = fakeDb({
      "storytimeConfig/familyVoice": {enabled: true},
      [voicePath]: {status: "consented"},
    });
    await flipVoiceToQueued(db, uid, voiceId, samplePaths);
    expect(updates).toEqual([
      {path: voicePath, data: expect.objectContaining({status: "queued", samplePaths})},
    ]);
  });

  it("allows re-queuing a previously failed voice", async () => {
    const {db, updates} = fakeDb({
      "storytimeConfig/familyVoice": {enabled: true},
      [voicePath]: {status: "failed"},
    });
    await flipVoiceToQueued(db, uid, voiceId, samplePaths);
    expect(updates[0].data.status).toBe("queued");
  });

  it("defaults family-voice to enabled when the config doc is missing", async () => {
    const {db, updates} = fakeDb({
      [voicePath]: {status: "consented"},
    });
    await flipVoiceToQueued(db, uid, voiceId, samplePaths);
    expect(updates).toHaveLength(1);
  });

  it("throws failed-precondition and writes nothing when family-voice is disabled", async () => {
    const {db, updates} = fakeDb({
      "storytimeConfig/familyVoice": {enabled: false},
      [voicePath]: {status: "consented"},
    });
    await expect(flipVoiceToQueued(db, uid, voiceId, samplePaths))
      .rejects.toMatchObject({code: "failed-precondition"});
    expect(updates).toHaveLength(0);
  });

  it("throws not-found and writes nothing when the voice doc doesn't exist", async () => {
    const {db, updates} = fakeDb({
      "storytimeConfig/familyVoice": {enabled: true},
    });
    await expect(flipVoiceToQueued(db, uid, voiceId, samplePaths))
      .rejects.toMatchObject({code: "not-found"});
    expect(updates).toHaveLength(0);
  });

  it("throws failed-precondition and writes nothing for a voice in an unqueueable status", async () => {
    for (const status of ["ready", "queued", "cloning"]) {
      const {db, updates} = fakeDb({
        "storytimeConfig/familyVoice": {enabled: true},
        [voicePath]: {status},
      });
      await expect(flipVoiceToQueued(db, uid, voiceId, samplePaths))
        .rejects.toMatchObject({code: "failed-precondition"});
      expect(updates).toHaveLength(0);
    }
  });
});
