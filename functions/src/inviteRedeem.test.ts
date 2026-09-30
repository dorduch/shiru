import {describe, expect, it, vi} from "vitest";
import type {Firestore} from "firebase-admin/firestore";
import {Timestamp} from "firebase-admin/firestore";
import {
  INVALID_REDEEM_MESSAGE,
  redeemVoiceInviteCore, requireInviteClaims,
} from "./inviteRedeem";
import {hashInviteToken} from "./domain";

type FakeDocData = Record<string, unknown> | undefined;
type Write = {path: string; data: Record<string, unknown>};

/**
 * Hand-rolled fake of the Firestore surfaces this module touches: plain
 * `db.doc(path).get()` reads, `db.collection("voiceInvites").where(...).get()`
 * (single-field equality lookup by `redeemedSyntheticUid`), and
 * `db.runTransaction` with `transaction.get()`/`transaction.update()`.
 *
 * Same disclaimer as voiceInvite.test.ts's fake: this does not enforce real
 * transactional semantics (read-before-write ordering, contention retries),
 * it only exercises this module's own branch logic and exact payloads.
 * IMPORTANT: unlike a naive copy of that fake, `runTransaction` here returns
 * whatever the callback returns — `redeemVoiceInviteCore` relies on that
 * return value to decide whether to throw, and the real Admin SDK does
 * return it, so mirroring that is required, not optional.
 */
function fakeDb(opts: {
  docs?: Record<string, FakeDocData>;
  inviteQueryResults?: {path: string; data: Record<string, unknown>}[];
}) {
  const docs = opts.docs ?? {};
  const inviteQueryResults = opts.inviteQueryResults ?? [];
  const writes: Write[] = [];

  function docRef(path: string) {
    return {
      path,
      get: async () => ({exists: docs[path] !== undefined, data: () => docs[path]}),
      update: async (data: Record<string, unknown>) => {
        writes.push({path, data});
        docs[path] = {...docs[path], ...data};
      },
    };
  }

  const db = {
    doc: (path: string) => docRef(path),
    collection: () => ({
      where: () => ({
        get: async () => ({
          docs: inviteQueryResults.map((r) => ({ref: docRef(r.path), data: () => r.data})),
        }),
      }),
    }),
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
        },
      };
      return fn(transaction);
    },
  };

  return {db: db as unknown as Firestore, writes};
}

const uid = "user1";
const voiceId = "voice1";
const voicePath = `users/${uid}/voices/${voiceId}`;
const token = "fixed-test-token";
const tokenHash = hashInviteToken(token);
const inviteDocPath = `voiceInvites/${tokenHash}`;
const syntheticUid = `invite:${tokenHash.slice(0, 32)}`;
const nowMillis = Date.UTC(2026, 6, 11, 12, 0, 0); // 2026-07-11T12:00:00Z

describe("redeemVoiceInviteCore", () => {
  it("happy path: redeems, mints a custom token with the pinned claims shape, and never leaks parentUid/voiceId", async () => {
    const expiresAt = Timestamp.fromMillis(nowMillis + 24 * 60 * 60 * 1000);
    const {db, writes} = fakeDb({
      docs: {
        [inviteDocPath]: {parentUid: uid, voiceId, status: "pending", expiresAt},
        [voicePath]: {name: "Grandma Rose", relationship: "Grandmother"},
      },
    });
    const createCustomToken = vi.fn(async () => "fake-custom-token");

    const result = await redeemVoiceInviteCore(db, token, nowMillis, createCustomToken);

    expect(createCustomToken).toHaveBeenCalledWith(syntheticUid, {invite: true, parentUid: uid, voiceId});
    expect(result).toMatchObject({
      kind: "session",
      customToken: "fake-custom-token",
      name: "Grandma Rose",
      relationship: "Grandmother",
      expiresAt: expiresAt.toDate().toISOString(),
      maxDurationSeconds: 15 * 60,
      maxBytes: 25 * 1024 * 1024,
    });
    expect(result).not.toHaveProperty("parentUid");
    expect(result).not.toHaveProperty("voiceId");
    expect(result).not.toHaveProperty("prompts");

    const flip = writes.find((w) => w.path === inviteDocPath);
    expect(flip).toBeTruthy();
    expect(flip!.data).toMatchObject({status: "redeemed", redeemedSyntheticUid: syntheticUid});
  });

  it("throws the generic message and writes nothing when the invite doc doesn't exist", async () => {
    const {db, writes} = fakeDb({docs: {}});
    const createCustomToken = vi.fn(async () => "unused");

    await expect(redeemVoiceInviteCore(db, token, nowMillis, createCustomToken))
      .rejects.toMatchObject({code: "failed-precondition", message: INVALID_REDEEM_MESSAGE});
    expect(writes).toHaveLength(0);
    expect(createCustomToken).not.toHaveBeenCalled();
  });

  it("throws the same generic message for a non-pending status (already redeemed / canceled / expired)", async () => {
    for (const status of ["redeemed", "canceled", "expired"]) {
      const expiresAt = Timestamp.fromMillis(nowMillis + 1000);
      const {db, writes} = fakeDb({
        docs: {[inviteDocPath]: {parentUid: uid, voiceId, status, expiresAt}},
      });
      await expect(redeemVoiceInviteCore(db, token, nowMillis, vi.fn()))
        .rejects.toMatchObject({code: "failed-precondition", message: INVALID_REDEEM_MESSAGE});
      expect(writes).toHaveLength(0);
    }
  });

  it("throws the same generic message when expired, AND flips the doc to status: expired", async () => {
    const expiresAt = Timestamp.fromMillis(nowMillis - 1); // already past
    const {db, writes} = fakeDb({
      docs: {[inviteDocPath]: {parentUid: uid, voiceId, status: "pending", expiresAt}},
    });
    const createCustomToken = vi.fn(async () => "unused");

    await expect(redeemVoiceInviteCore(db, token, nowMillis, createCustomToken))
      .rejects.toMatchObject({code: "failed-precondition", message: INVALID_REDEEM_MESSAGE});
    expect(createCustomToken).not.toHaveBeenCalled();

    const flip = writes.find((w) => w.path === inviteDocPath);
    expect(flip).toBeTruthy();
    expect(flip!.data).toEqual({status: "expired"});
  });

  it("defaults name/relationship to empty strings if the voice doc is missing fields", async () => {
    const expiresAt = Timestamp.fromMillis(nowMillis + 1000);
    const {db} = fakeDb({
      docs: {
        [inviteDocPath]: {parentUid: uid, voiceId, status: "pending", expiresAt},
        [voicePath]: {},
      },
    });
    const result = await redeemVoiceInviteCore(db, token, nowMillis, vi.fn(async () => "tok"));
    expect(result.kind).toBe("session");
    expect(result.name).toBe("");
    expect(result.relationship).toBe("");
  });
});

describe("requireInviteClaims", () => {
  it("returns parentUid/voiceId/syntheticUid from verified token claims", () => {
    const claims = requireInviteClaims({
      auth: {uid: syntheticUid, token: {invite: true, parentUid: uid, voiceId}},
    });
    expect(claims).toEqual({parentUid: uid, voiceId, syntheticUid});
  });

  it("rejects a request with no auth at all", () => {
    expect(() => requireInviteClaims({})).toThrowError(
      expect.objectContaining({code: "unauthenticated"}),
    );
  });

  it("rejects a normal signed-in user without the invite claim", () => {
    expect(() => requireInviteClaims({auth: {uid: "some-real-user", token: {}}}))
      .toThrowError(expect.objectContaining({code: "unauthenticated"}));
  });

  it("rejects invite: false explicitly", () => {
    expect(() => requireInviteClaims({auth: {uid: syntheticUid, token: {invite: false, parentUid: uid, voiceId}}}))
      .toThrowError(expect.objectContaining({code: "unauthenticated"}));
  });

  it("rejects a token missing parentUid/voiceId even if invite is true", () => {
    expect(() => requireInviteClaims({auth: {uid: syntheticUid, token: {invite: true}}}))
      .toThrowError(expect.objectContaining({code: "unauthenticated"}));
  });
});

describe("redeemVoiceInviteCore status reopen", () => {
  it("returns Pending / Approved / Not approved from the relativeReadings doc", async () => {
    const readingId = "abc123def4567890";
    const readingPath = `users/${uid}/relativeReadings/${readingId}`;
    for (const [status, expected] of [
      ["pending", "pending"],
      ["approved", "approved"],
      ["rejected", "rejected"],
      ["weird", "pending"],
    ] as const) {
      const {db} = fakeDb({
        docs: {
          [inviteDocPath]: {
            parentUid: uid, voiceId, status: "submitted", readingId,
            expiresAt: Timestamp.fromMillis(nowMillis + 60_000),
          },
          [voicePath]: {name: "Gran", relationship: "grandma"},
          [readingPath]: {status, storagePath: "x"},
        },
      });
      const result = await redeemVoiceInviteCore(db, token, nowMillis, vi.fn());
      expect(result).toEqual({
        kind: "status",
        approvalStatus: expected,
        name: "Gran",
        relationship: "grandma",
      });
    }
  });
});
