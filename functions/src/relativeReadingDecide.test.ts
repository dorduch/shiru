import {describe, expect, it, vi} from "vitest";
import type {Firestore} from "firebase-admin/firestore";
import {
  decideRelativeReadingCore,
  getRelativeReadingAudioUrlCore,
} from "./relativeReadingDecide";

type FakeDocData = Record<string, unknown> | undefined;

function fakeDb(docs: Record<string, FakeDocData> = {}) {
  const writes: {path: string; data: Record<string, unknown>}[] = [];

  function docRef(path: string) {
    return {
      path,
      get: async () => ({exists: docs[path] !== undefined, data: () => docs[path]}),
    };
  }

  const db = {
    doc: (path: string) => docRef(path),
    runTransaction: async (
      fn: (transaction: {
        get: (ref: {get: () => Promise<unknown>}) => Promise<unknown>;
        update: (ref: {path: string}, data: Record<string, unknown>) => void;
      }) => Promise<unknown>,
    ) => {
      const transaction = {
        get: async (ref: {get: () => Promise<unknown>}) => ref.get(),
        update: (ref: {path: string}, data: Record<string, unknown>) => {
          writes.push({path: ref.path, data});
          docs[ref.path] = {...(docs[ref.path] ?? {}), ...data};
        },
      };
      return fn(transaction);
    },
  };

  return {db: db as unknown as Firestore, writes, docs};
}

const parentUid = "parent1";
const readingId = "abc123def4567890";
const readingPath = `users/${parentUid}/relativeReadings/${readingId}`;
const nowMillis = Date.UTC(2026, 8, 30, 12, 0, 0);
const storagePath = `relative-readings/${parentUid}/${readingId}/reading.webm`;

function pendingDoc(overrides: Record<string, unknown> = {}) {
  return {
    voiceId: "voice1",
    name: "Grandma",
    relationship: "grandma",
    status: "pending",
    storagePath,
    mimeType: "audio/webm",
    byteSize: 1024,
    durationSeconds: 90,
    ...overrides,
  };
}

describe("getRelativeReadingAudioUrlCore", () => {
  it("returns a signed URL for a pending reading", async () => {
    const {db} = fakeDb({[readingPath]: pendingDoc()});
    const getSignedUrl = vi.fn(async () => "https://signed.example/audio");
    const result = await getRelativeReadingAudioUrlCore(
      db, getSignedUrl, parentUid, readingId, nowMillis,
    );
    expect(result).toMatchObject({
      readingId,
      downloadUrl: "https://signed.example/audio",
      mimeType: "audio/webm",
      status: "pending",
      name: "Grandma",
      relationship: "grandma",
      durationSeconds: 90,
    });
    expect(getSignedUrl).toHaveBeenCalledWith(storagePath, expect.any(Date));
  });

  it("refuses a rejected reading (no library path)", async () => {
    const {db} = fakeDb({[readingPath]: pendingDoc({status: "rejected"})});
    await expect(
      getRelativeReadingAudioUrlCore(db, vi.fn(), parentUid, readingId, nowMillis),
    ).rejects.toMatchObject({code: "failed-precondition"});
  });

  it("throws not-found when the doc is missing", async () => {
    const {db} = fakeDb();
    await expect(
      getRelativeReadingAudioUrlCore(db, vi.fn(), parentUid, readingId, nowMillis),
    ).rejects.toMatchObject({code: "not-found"});
  });
});

describe("decideRelativeReadingCore", () => {
  it("approve: pending → approved and returns a signed URL", async () => {
    const {db, writes} = fakeDb({[readingPath]: pendingDoc()});
    const getSignedUrl = vi.fn(async () => "https://signed.example/ok");
    const result = await decideRelativeReadingCore(
      db, getSignedUrl, parentUid, readingId, "approve", nowMillis,
    );
    expect(result.status).toBe("approved");
    expect(result.downloadUrl).toBe("https://signed.example/ok");
    expect(writes[0]?.data).toMatchObject({status: "approved"});
  });

  it("approve: idempotent when already approved", async () => {
    const {db, writes} = fakeDb({[readingPath]: pendingDoc({status: "approved"})});
    const result = await decideRelativeReadingCore(
      db, vi.fn(async () => "https://signed.example/again"), parentUid, readingId, "approve", nowMillis,
    );
    expect(result.status).toBe("approved");
    expect(result.downloadUrl).toBe("https://signed.example/again");
    expect(writes).toHaveLength(0);
  });

  it("reject: pending → rejected with no download URL", async () => {
    const {db, writes} = fakeDb({[readingPath]: pendingDoc()});
    const result = await decideRelativeReadingCore(
      db, vi.fn(), parentUid, readingId, "reject", nowMillis,
    );
    expect(result).toMatchObject({status: "rejected", downloadUrl: null});
    expect(writes[0]?.data).toMatchObject({status: "rejected"});
  });

  it("reject: idempotent when already rejected", async () => {
    const {db, writes} = fakeDb({[readingPath]: pendingDoc({status: "rejected"})});
    const result = await decideRelativeReadingCore(
      db, vi.fn(), parentUid, readingId, "reject", nowMillis,
    );
    expect(result.status).toBe("rejected");
    expect(writes).toHaveLength(0);
  });

  it("blocks approve after reject", async () => {
    const {db} = fakeDb({[readingPath]: pendingDoc({status: "rejected"})});
    await expect(
      decideRelativeReadingCore(db, vi.fn(), parentUid, readingId, "approve", nowMillis),
    ).rejects.toMatchObject({code: "failed-precondition"});
  });

  it("blocks reject after approve", async () => {
    const {db} = fakeDb({[readingPath]: pendingDoc({status: "approved"})});
    await expect(
      decideRelativeReadingCore(db, vi.fn(), parentUid, readingId, "reject", nowMillis),
    ).rejects.toMatchObject({code: "failed-precondition"});
  });
});
