// Relative Readings MVP — full-story invite capture page.
// Contracts: redeemVoiceInvite (session | status), prepareStoryInviteUpload,
// submitStoryInviteReading. Upload goes through Firebase Storage SDK under
// invite custom-token claims (25MB exceeds callable payload limits).

import {
  initializeApp,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import {
  getAuth,
  signInWithCustomToken,
  onAuthStateChanged,
  getIdTokenResult,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import {
  getFunctions,
  httpsCallable,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-functions.js";
import {
  getStorage,
  ref as storageRef,
  uploadBytes,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-storage.js";

const firebaseConfig = {
  apiKey: "AIzaSyBvT3Kf4GTcTd5VYlG_fE7-JI9ft4GkbZU",
  authDomain: "shiru-bcdd2.firebaseapp.com",
  projectId: "shiru-bcdd2",
  storageBucket: "shiru-bcdd2.firebasestorage.app",
  messagingSenderId: "310525193859",
  appId: "1:310525193859:web:19b1a756d21bbc656475b6",
};

const DEFAULT_MAX_DURATION_SECONDS = 15 * 60;
const DEFAULT_MAX_BYTES = 25 * 1024 * 1024;
const ALLOWED_MIMES = new Set(["audio/webm", "audio/mp4", "audio/aac"]);

const root = document.getElementById("app");

/** @type {{
 *  phase: "redeeming"|"invalid"|"form"|"recording"|"review"|"uploading"|"upload_error"|"status",
 *  errorMessage: string,
 *  invite: null | {
 *    name: string,
 *    relationship: string,
 *    expiresAt: string,
 *    maxDurationSeconds: number,
 *    maxBytes: number,
 *    allowedMimeTypes: string[],
 *  },
 *  approvalStatus: ""|"pending"|"approved"|"rejected",
 *  consentChecked: boolean,
 *  micDenied: boolean,
 *  hardStopped: boolean,
 *  elapsedSeconds: number,
 *  blob: Blob|null,
 *  mimeType: string,
 *  audioUrl: string|null,
 *  durationSeconds: number|null,
 *  blockedMessage: string,
 * }}
 */
const state = {
  phase: "redeeming",
  errorMessage: "",
  invite: null,
  approvalStatus: "",
  consentChecked: false,
  micDenied: false,
  hardStopped: false,
  elapsedSeconds: 0,
  blob: null,
  mimeType: "",
  audioUrl: null,
  durationSeconds: null,
  blockedMessage: "",
};

let auth = null;
let functionsInstance = null;
let storageInstance = null;
let redeemVoiceInviteFn = null;
let prepareStoryInviteUploadFn = null;
let submitStoryInviteReadingFn = null;
let currentToken = "";
let mediaRecorder = null;
let mediaStream = null;
let recordChunks = [];
let recordTimerId = null;
let recordStartedAt = 0;
let uploading = false;

function extractToken() {
  const match = location.pathname.match(/\/invite\/([^/]+)\/?$/);
  if (!match) return "";
  const raw = match[1];
  if (!raw || raw.toLowerCase() === "index.html") return "";
  try {
    return decodeURIComponent(raw);
  } catch {
    return raw;
  }
}

const SESSION_STORAGE_PREFIX = "shiruRelativeReadingInvite:v1:";

function sessionStorageKey(token) {
  return SESSION_STORAGE_PREFIX + token;
}

function readStoredSession(token) {
  let raw;
  try {
    raw = sessionStorage.getItem(sessionStorageKey(token));
  } catch {
    return null;
  }
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || parsed.token !== token) return null;
    return parsed;
  } catch {
    return null;
  }
}

function saveStoredSession(token, patch) {
  const existing = readStoredSession(token) || {token};
  const next = {...existing, ...patch, token};
  try {
    sessionStorage.setItem(sessionStorageKey(token), JSON.stringify(next));
  } catch {
    // best-effort
  }
}

function clearStoredSession(token) {
  try {
    sessionStorage.removeItem(sessionStorageKey(token));
  } catch {
    // ignore
  }
}

function waitForAuthInit(authInstance) {
  return new Promise((resolve) => {
    const unsubscribe = onAuthStateChanged(authInstance, (user) => {
      unsubscribe();
      resolve(user);
    });
  });
}

async function hasLiveInviteClaims(user) {
  if (!user) return false;
  try {
    const result = await getIdTokenResult(user);
    return result?.claims?.invite === true;
  } catch {
    return false;
  }
}

function normalizeMimeType(mimeType) {
  return (mimeType || "").split(";")[0].trim();
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function formatExpiry(iso) {
  try {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return "soon";
    return `on ${d.toLocaleDateString(undefined, {year: "numeric", month: "long", day: "numeric"})}`;
  } catch {
    return "soon";
  }
}

function formatClock(totalSeconds) {
  const s = Math.max(0, Math.floor(totalSeconds));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
}

function maxDuration() {
  return state.invite?.maxDurationSeconds || DEFAULT_MAX_DURATION_SECONDS;
}

function maxBytes() {
  return state.invite?.maxBytes || DEFAULT_MAX_BYTES;
}

function isMimeAllowed(mimeType) {
  const allowed = state.invite?.allowedMimeTypes;
  if (Array.isArray(allowed) && allowed.length > 0) {
    return allowed.includes(mimeType);
  }
  return ALLOWED_MIMES.has(mimeType);
}

function describeMimeBlock(mimeType) {
  return `That audio format (${mimeType || "unknown"}) isn't supported. Please use webm, m4a, or aac.`;
}

function describeSizeBlock(bytes) {
  const mb = (bytes / (1024 * 1024)).toFixed(1);
  return `That recording is ${mb} MB — the limit is 25 MB. Please re-record a shorter reading.`;
}

function validateBlobOrReason(blob, mimeType) {
  if (!blob) return "Please record a story reading first.";
  if (!isMimeAllowed(mimeType)) return describeMimeBlock(mimeType);
  if (blob.size > maxBytes()) return describeSizeBlock(blob.size);
  if (blob.size <= 0) return "That recording is empty. Please try again.";
  return "";
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------


Object.assign(globalThis.__RR = globalThis.__RR || {}, {
  ALLOWED_MIMES,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_DURATION_SECONDS,
  SESSION_STORAGE_PREFIX,
  auth,
  clearStoredSession,
  currentToken,
  describeMimeBlock,
  describeSizeBlock,
  escapeHtml,
  extractToken,
  firebaseConfig,
  formatClock,
  formatExpiry,
  functionsInstance,
  hasLiveInviteClaims,
  isMimeAllowed,
  maxBytes,
  maxDuration,
  mediaRecorder,
  mediaStream,
  normalizeMimeType,
  prepareStoryInviteUploadFn,
  readStoredSession,
  recordChunks,
  recordStartedAt,
  recordTimerId,
  redeemVoiceInviteFn,
  root,
  saveStoredSession,
  sessionStorageKey,
  state,
  storageInstance,
  submitStoryInviteReadingFn,
  uploading,
  validateBlobOrReason,
  waitForAuthInit
});

// Load follow-on scripts after Firebase imports resolve.
// 1a/1b are classic (share globals via __RR); 2 is module (needs Firebase imports).
await (async () => {
  async function loadScript(src, {module = false} = {}) {
    await new Promise((resolve, reject) => {
      const s = document.createElement("script");
      if (module) s.type = "module";
      s.src = src;
      s.onload = resolve;
      s.onerror = () => reject(new Error("Failed to load " + src));
      document.body.appendChild(s);
    });
  }
  await loadScript("./invite-1a.js");
  await loadScript("./invite-1b.js");
  await loadScript("./invite-2.js", {module: true});
})();
