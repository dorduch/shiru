import {describe, expect, it} from "vitest";
import type {Firestore} from "firebase-admin/firestore";
import {createVoiceInviteCore, inviteUrl} from "./voiceInvite";
import {hashInviteToken} from "./domain";

type FakeDocData = Record<string, unknown> | undefined;
type Write = {type: "set" | "create" | "update"; path: string; data: Record<string, unknown>};

/**
 * Hand-rolled fake of the Firestore surfaces `createVoiceInviteCore` touches:
 * plain `db.doc(path).get()` reads (family-voice config, voice doc), and,
 * inside `db.runTransaction`, `transaction.get()` on both a doc ref (the
 * quota doc) and a 3-way `.where().where().where()` query (the pending-invite
 * supersede lookup), followed by `transaction.set/create/update`.
 *
 * This is NOT a faithful Firestore emulation: it does not enforce the
 * "all reads before any writes" transaction rule, nor does it retry on
 * contention. It exists to exercise the function's own logic (branch
 * conditions, exact doc paths/payloads) in isolation. The real transactional
 * behavior — read/write ordering legality, actual atomicity, composite index
 * usage — still needs emulator coverage (flagged for Task 9).
 */
function fakeDb(opts: {
  docs?: Record<string, FakeDocData>;
  pendingInvites?: {path: string; data: Record<string, unknown>}[];
}) {
  const docs = opts.docs ?? {};
  const pendingInvites = opts.pendingInvites ?? [];
  const writes: Write[] = [];

  function docRef(path: string) {
    return {
      path,
      get: async () => ({exists: docs[path] !== undefined, data: () => docs[path]}),
    };
  }

  const pendingQueryMarker = {_isPendingQuery: true as const};

  const db = {
    doc: (path: string) => docRef(path),
    collection: () => ({
      where: () => ({
        where: () => ({
          where: () => pendingQueryMarker,
        }),
      }),
    }),
    runTransaction: async (
      fn: (transaction: {
        get: (refOrQuery: unknown) => Promise<unknown>;
        set: (ref: {path: string}, data: Record<string, unknown>) => void;
        create: (ref: {path: string}, data: Record<string, unknown>) => void;
        update: (ref: {path: string}, data: Record<string, unknown>) => void;
      }) => Promise<void>,
    ) => {
      const transaction = {
        get: async (refOrQuery: unknown) => {
          if (refOrQuery === pendingQueryMarker) {
            return {
              docs: pendingInvites.map((inv) => ({
                ref: docRef(inv.path),
                data: () => inv.data,
              })),
            };
          }
          return (refOrQuery as {get: () => Promise<unknown>}).get();
        },
        set: (ref: {path: string}, data: Record<string, unknown>) => {
          writes.push({type: "set", path: ref.path, data});
        },
        create: (ref: {path: string}, data: Record<string, unknown>) => {
          writes.push({type: "create", path: ref.path, data});
        },
        update: (ref: {path: string}, data: Record<string, unknown>) => {
          writes.push({type: "update", path: ref.path, data});
        },
      };
      await fn(transaction);
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
const nowMillis = Date.UTC(2026, 6, 11, 12, 0, 0); // 2026-07-11T12:00:00Z
const quotaPath = `users/${uid}/inviteQuota/2026-07-11`;
const host = "https://example.test";

describe("inviteUrl", () => {
  it("joins host and token under /invite/", () => {
    expect(inviteUrl("https://example.test", "abc123")).toBe("https://example.test/invite/abc123");
  });
});

describe("createVoiceInviteCore", () => {
  it("happy path: writes the invite doc with the pinned shape and returns a well-formed url/expiry", async () => {
    const {db, writes} = fakeDb({
      docs: {
        "storytimeConfig/familyVoice": {enabled: true},
        [voicePath]: {status: "consented"},
      },
    });

    const result = await createVoiceInviteCore(db, uid, voiceId, token, nowMillis, host);

    expect(result.url).toBe(`https://example.test/invite/${token}`);
    expect(result.expiresAt.toMillis()).toBe(nowMillis + 7 * 24 * 60 * 60 * 1000);

    const create = writes.find((w) => w.type === "create" && w.path === inviteDocPath);
    expect(create).toBeTruthy();
    expect(create!.data).toMatchObject({
      parentUid: uid,
      voiceId,
      status: "pending",
      redeemedAt: null,
      redeemedSyntheticUid: null,
    });
    expect((create!.data.expiresAt as {toMillis: () => number}).toMillis())
      .toBe(nowMillis + 7 * 24 * 60 * 60 * 1000);

    const quotaSet = writes.find((w) => w.type === "set" && w.path === quotaPath);
    expect(quotaSet).toBeTruthy();
    expect(quotaSet!.data.reserved).toBe(1);
  });

  it("allows a previously-failed voice to be (re)invited", async () => {
    const {db, writes} = fakeDb({
      docs: {
        "storytimeConfig/familyVoice": {enabled: true},
        [voicePath]: {status: "failed"},
      },
    });

    await createVoiceInviteCore(db, uid, voiceId, token, nowMillis, host);
    expect(writes.some((w) => w.type === "create" && w.path === inviteDocPath)).toBe(true);
  });

  it("throws not-found when the voice doc doesn't exist", async () => {
    const {db, writes} = fakeDb({
      docs: {"storytimeConfig/familyVoice": {enabled: true}},
    });

    await expect(createVoiceInviteCore(db, uid, voiceId, token, nowMillis, host))
      .rejects.toMatchObject({code: "not-found"});
    expect(writes).toHaveLength(0);
  });

  it("throws failed-precondition for a voice in an un-inviteable status", async () => {
    for (const status of ["ready", "queued", "cloning"]) {
      const {db, writes} = fakeDb({
        docs: {
          "storytimeConfig/familyVoice": {enabled: true},
          [voicePath]: {status},
        },
      });
      await expect(createVoiceInviteCore(db, uid, voiceId, token, nowMillis, host))
        .rejects.toMatchObject({code: "failed-precondition"});
      expect(writes).toHaveLength(0);
    }
  });

  it("throws invalid-argument when family voice is disabled", async () => {
    const {db, writes} = fakeDb({
      docs: {
        "storytimeConfig/familyVoice": {enabled: false},
        [voicePath]: {status: "consented"},
      },
    });

    await expect(createVoiceInviteCore(db, uid, voiceId, token, nowMillis, host))
      .rejects.toMatchObject({code: "invalid-argument"});
    expect(writes).toHaveLength(0);
  });

  it("throws resource-exhausted once the daily quota is reached", async () => {
    const {db, writes} = fakeDb({
      docs: {
        "storytimeConfig/familyVoice": {enabled: true},
        [voicePath]: {status: "consented"},
        [quotaPath]: {reserved: 5},
      },
    });

    await expect(createVoiceInviteCore(db, uid, voiceId, token, nowMillis, host))
      .rejects.toMatchObject({code: "resource-exhausted"});
    expect(writes).toHaveLength(0);
  });

  it("cancels an existing pending invite for the same voice (supersede)", async () => {
    const oldInvitePath = "voiceInvites/old-hash";
    const {db, writes} = fakeDb({
      docs: {
        "storytimeConfig/familyVoice": {enabled: true},
        [voicePath]: {status: "consented"},
      },
      pendingInvites: [
        {path: oldInvitePath, data: {parentUid: uid, voiceId, status: "pending"}},
      ],
    });

    await createVoiceInviteCore(db, uid, voiceId, token, nowMillis, host);

    const cancelWrite = writes.find((w) => w.type === "update" && w.path === oldInvitePath);
    expect(cancelWrite).toBeTruthy();
    expect(cancelWrite!.data).toEqual({status: "canceled"});

    // The new invite is still created alongside the supersede.
    expect(writes.some((w) => w.type === "create" && w.path === inviteDocPath)).toBe(true);
  });
});
