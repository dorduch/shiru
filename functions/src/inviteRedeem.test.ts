import {describe, expect, it, vi} from "vitest";
import type {Firestore} from "firebase-admin/firestore";
import {Timestamp} from "firebase-admin/firestore";
import {
  INVALID_REDEEM_MESSAGE, INVALID_SESSION_MESSAGE, INVITE_PROMPTS,
  redeemVoiceInviteCore, requireInviteClaims, submitVoiceInviteCore, uploadVoiceInviteSampleCore,
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
    expect(result.customToken).toBe("fake-custom-token");
    expect(result.name).toBe("Grandma Rose");
    expect(result.relationship).toBe("Grandmother");
    expect(result.prompts).toEqual(INVITE_PROMPTS);
    expect(result.expiresAt).toBe(expiresAt.toDate().toISOString());
    expect(result).not.toHaveProperty("parentUid");
    expect(result).not.toHaveProperty("voiceId");

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

describe("submitVoiceInviteCore", () => {
  function fakeBucket(files: string[]) {
    const calls: {prefix: string}[] = [];
    return {
      bucket: {
        getFiles: async (options: {prefix: string}) => {
          calls.push(options);
          return [files.map((name) => ({name}))] as [{name: string}[]];
        },
      },
      calls,
    };
  }

  it("happy path: lists Storage samples and calls flipVoiceToQueued with them", async () => {
    const redeemedAt = Timestamp.fromMillis(nowMillis - 60 * 1000); // 1 min ago
    const {db, writes} = fakeDb({
      docs: {
        "storytimeConfig/familyVoice": {enabled: true},
        [voicePath]: {status: "consented"},
      },
      inviteQueryResults: [
        {path: inviteDocPath, data: {parentUid: uid, voiceId, status: "redeemed", redeemedAt}},
      ],
    });
    const samplePaths = [
      `voice-samples/${uid}/${voiceId}/0.webm`,
      `voice-samples/${uid}/${voiceId}/1.webm`,
    ];
    const {bucket, calls} = fakeBucket(samplePaths);

    await expect(submitVoiceInviteCore(db, bucket, uid, voiceId, syntheticUid, nowMillis))
      .resolves.toBeUndefined();
    expect(calls).toEqual([{prefix: `voice-samples/${uid}/${voiceId}/`}]);

    const flip = writes.find((w) => w.path === voicePath);
    expect(flip).toBeTruthy();
    expect(flip!.data).toMatchObject({status: "queued", samplePaths});
  });

  it("rejects when there is no redeemed invite doc for this synthetic uid", async () => {
    const {db} = fakeDb({inviteQueryResults: []});
    const {bucket} = fakeBucket([]);
    await expect(submitVoiceInviteCore(db, bucket, uid, voiceId, syntheticUid, nowMillis))
      .rejects.toMatchObject({code: "failed-precondition", message: INVALID_SESSION_MESSAGE});
  });

  it("rejects when the invite doc's redeemedAt is outside the 2h window", async () => {
    const redeemedAt = Timestamp.fromMillis(nowMillis - 2 * 60 * 60 * 1000 - 1); // just over 2h ago
    const {db} = fakeDb({
      inviteQueryResults: [
        {path: inviteDocPath, data: {parentUid: uid, voiceId, status: "redeemed", redeemedAt}},
      ],
    });
    const {bucket} = fakeBucket(["voice-samples/x"]);
    await expect(submitVoiceInviteCore(db, bucket, uid, voiceId, syntheticUid, nowMillis))
      .rejects.toMatchObject({code: "failed-precondition", message: INVALID_SESSION_MESSAGE});
  });

  it("rejects when the invite doc's parentUid/voiceId don't match the claims", async () => {
    const redeemedAt = Timestamp.fromMillis(nowMillis - 1000);
    const {db} = fakeDb({
      inviteQueryResults: [
        {path: inviteDocPath, data: {parentUid: "someone-else", voiceId, status: "redeemed", redeemedAt}},
      ],
    });
    const {bucket} = fakeBucket(["voice-samples/x"]);
    await expect(submitVoiceInviteCore(db, bucket, uid, voiceId, syntheticUid, nowMillis))
      .rejects.toMatchObject({code: "failed-precondition", message: INVALID_SESSION_MESSAGE});
  });

  it("rejects when no sample files were found in Storage", async () => {
    const redeemedAt = Timestamp.fromMillis(nowMillis - 1000);
    const {db} = fakeDb({
      docs: {
        "storytimeConfig/familyVoice": {enabled: true},
        [voicePath]: {status: "consented"},
      },
      inviteQueryResults: [
        {path: inviteDocPath, data: {parentUid: uid, voiceId, status: "redeemed", redeemedAt}},
      ],
    });
    const {bucket} = fakeBucket([]);
    await expect(submitVoiceInviteCore(db, bucket, uid, voiceId, syntheticUid, nowMillis))
      .rejects.toMatchObject({code: "failed-precondition"});
  });
});

describe("uploadVoiceInviteSampleCore", () => {
  function activeSessionDb() {
    const redeemedAt = Timestamp.fromMillis(nowMillis - 1000);
    return fakeDb({
      inviteQueryResults: [
        {path: inviteDocPath, data: {parentUid: uid, voiceId, status: "redeemed", redeemedAt}},
      ],
    }).db;
  }

  function fakeBucket() {
    const calls: {path: string; buf: Buffer; opts: {contentType: string}}[] = [];
    return {
      bucket: {
        file: (path: string) => ({
          save: async (buf: Buffer, opts: {contentType: string}) => {
            calls.push({path, buf, opts});
          },
        }),
      },
      calls,
    };
  }

  it("happy path: saves to the expected path with the given contentType", async () => {
    const db = activeSessionDb();
    const {bucket, calls} = fakeBucket();
    const base64 = Buffer.from("hello-audio-bytes").toString("base64");

    const result = await uploadVoiceInviteSampleCore(
      db, bucket, uid, voiceId, syntheticUid, nowMillis, 2, base64, "audio/webm",
    );

    expect(result.path).toBe(`voice-samples/${uid}/${voiceId}/2.webm`);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`voice-samples/${uid}/${voiceId}/2.webm`);
    expect(calls[0].opts).toEqual({contentType: "audio/webm"});
    expect(calls[0].buf.toString()).toBe("hello-audio-bytes");
  });

  it("maps audio/mp4 to a .m4a path", async () => {
    const db = activeSessionDb();
    const {bucket, calls} = fakeBucket();
    const base64 = Buffer.from("x").toString("base64");

    const result = await uploadVoiceInviteSampleCore(
      db, bucket, uid, voiceId, syntheticUid, nowMillis, 0, base64, "audio/mp4",
    );
    expect(result.path).toBe(`voice-samples/${uid}/${voiceId}/0.m4a`);
    expect(calls[0].opts).toEqual({contentType: "audio/mp4"});
  });

  it("rejects idx out of range (negative, >4, non-integer)", async () => {
    const db = activeSessionDb();
    const {bucket, calls} = fakeBucket();
    const base64 = Buffer.from("x").toString("base64");

    for (const idx of [-1, 5, 1.5]) {
      await expect(uploadVoiceInviteSampleCore(db, bucket, uid, voiceId, syntheticUid, nowMillis, idx, base64, "audio/webm"))
        .rejects.toMatchObject({code: "invalid-argument"});
    }
    expect(calls).toHaveLength(0);
  });

  it("rejects an oversized decoded payload (> 8MB)", async () => {
    const db = activeSessionDb();
    const {bucket, calls} = fakeBucket();
    const big = Buffer.alloc(8 * 1024 * 1024 + 1, 1).toString("base64");

    await expect(uploadVoiceInviteSampleCore(db, bucket, uid, voiceId, syntheticUid, nowMillis, 0, big, "audio/webm"))
      .rejects.toMatchObject({code: "invalid-argument"});
    expect(calls).toHaveLength(0);
  });

  it("rejects an unsupported mimeType", async () => {
    const db = activeSessionDb();
    const {bucket, calls} = fakeBucket();
    const base64 = Buffer.from("x").toString("base64");

    await expect(uploadVoiceInviteSampleCore(db, bucket, uid, voiceId, syntheticUid, nowMillis, 0, base64, "audio/wav"))
      .rejects.toMatchObject({code: "invalid-argument"});
    expect(calls).toHaveLength(0);
  });

  it("rejects when the invite session is stale (outside the 2h window), even with valid arguments", async () => {
    const redeemedAt = Timestamp.fromMillis(nowMillis - 3 * 60 * 60 * 1000);
    const {db} = fakeDb({
      inviteQueryResults: [
        {path: inviteDocPath, data: {parentUid: uid, voiceId, status: "redeemed", redeemedAt}},
      ],
    });
    const {bucket, calls} = fakeBucket();
    const base64 = Buffer.from("x").toString("base64");

    await expect(uploadVoiceInviteSampleCore(db, bucket, uid, voiceId, syntheticUid, nowMillis, 0, base64, "audio/webm"))
      .rejects.toMatchObject({code: "failed-precondition", message: INVALID_SESSION_MESSAGE});
    expect(calls).toHaveLength(0);
  });
});
