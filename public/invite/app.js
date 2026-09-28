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

function render() {
  switch (state.phase) {
    case "redeeming":
      root.innerHTML = renderRedeeming();
      break;
    case "invalid":
      root.innerHTML = renderInvalid();
      break;
    case "status":
      root.innerHTML = renderStatus();
      break;
    case "form":
    case "recording":
    case "review":
    case "uploading":
    case "upload_error":
      root.innerHTML = renderCapture();
      break;
    default:
      root.innerHTML = renderInvalid();
  }
}

function renderRedeeming() {
  return `
    <section class="screen screen-center" aria-busy="true">
      <div class="spinner" aria-hidden="true"></div>
      <p class="loading-line">Checking your invite…</p>
    </section>
  `;
}

function renderInvalid() {
  return `
    <section class="screen screen-center">
      <h1>Link not available</h1>
      <p>${escapeHtml(state.errorMessage || "This invite link is no longer valid.")}</p>
      <p class="muted">Ask the person who sent it to send a new link.</p>
    </section>
  `;
}

function renderStatus() {
  const labels = {
    pending: "Pending",
    approved: "Approved",
    rejected: "Not approved",
  };
  const status = state.approvalStatus || "pending";
  const label = labels[status] || "Pending";
  const detail = {
    pending: "Your reading was sent. A parent will review it soon — you can close this page.",
    approved: "Your reading was approved and is ready for the child. Thank you!",
    rejected: "This reading wasn't approved. You can close this page.",
  }[status] || "";

  return `
    <section class="screen screen-center">
      <div class="success-check" aria-hidden="true">${status === "rejected" ? "!" : "&#10003;"}</div>
      <h1>${escapeHtml(label)}</h1>
      <p>${escapeHtml(detail)}</p>
    </section>
  `;
}

function renderCapture() {
  const invite = state.invite || {name: "", relationship: "", expiresAt: ""};
  const recording = state.phase === "recording";
  const reviewing = state.phase === "review" || state.phase === "upload_error" || state.phase === "uploading";
  const uploadingNow = state.phase === "uploading";
  const relationshipLine = invite.relationship
    ? `<p class="header-sub">Relationship: ${escapeHtml(invite.relationship)}</p>`
    : "";
  const expiresLine = invite.expiresAt
    ? `<p class="muted small">This link expires ${escapeHtml(formatExpiry(invite.expiresAt))}.</p>`
    : "";

  const blockedBanner = state.blockedMessage
    ? `<div class="banner banner-warn" role="alert">${escapeHtml(state.blockedMessage)}</div>`
    : "";

  const errorBanner = state.phase === "upload_error"
    ? `
      <div class="banner banner-error" role="alert">
        <p>${escapeHtml(state.errorMessage || "Something went wrong while sending. Please try again.")}</p>
        <button type="button" class="btn btn-secondary" data-action="retry">Retry</button>
      </div>
    `
    : "";

  const hardStopBanner = state.hardStopped
    ? `<div class="banner banner-warn" role="status">That's the limit — review or re-record.</div>`
    : "";

  let bodyHtml = "";
  if (recording) {
    bodyHtml = `
      <article class="prompt-card record-card">
        <div class="prompt-card-head">
          <span class="prompt-number">Recording</span>
          <span class="badge badge-live">Live</span>
        </div>
        <p class="timer" aria-live="polite">${formatClock(state.elapsedSeconds)}
          <span class="muted small"> / ${formatClock(maxDuration())}</span>
        </p>
        <p class="muted">Up to 15 minutes</p>
        <div class="prompt-controls">
          <button type="button" class="btn btn-stop" data-action="stop">Stop recording</button>
        </div>
      </article>
    `;
  } else if (reviewing && state.blob) {
    const audioSrc = state.audioUrl
      ? `<audio class="playback" controls src="${state.audioUrl}"></audio>`
      : "";
    bodyHtml = `
      <article class="prompt-card record-card">
        <div class="prompt-card-head">
          <span class="prompt-number">Your reading</span>
          <span class="badge badge-recorded">Ready</span>
        </div>
        <p class="muted">Length: ${formatClock(state.durationSeconds || state.elapsedSeconds || 0)}
          · ${(state.blob.size / (1024 * 1024)).toFixed(1)} MB</p>
        ${audioSrc}
        <div class="prompt-controls">
          <button type="button" class="btn btn-secondary" data-action="rerecord" ${uploadingNow ? "disabled" : ""}>
            Re-record
          </button>
        </div>
      </article>
    `;
  } else {
    const fileFallback = state.micDenied
      ? `
        <p class="mic-fallback-note">Microphone isn't available. Choose an audio file instead (webm, m4a, or aac · up to 25 MB · up to 15 minutes).</p>
        <label class="btn btn-secondary file-label" for="file-input">Choose audio file</label>
        <input type="file" id="file-input" class="visually-hidden-input" accept="audio/webm,audio/mp4,audio/aac,audio/*" aria-label="Upload a story reading" />
      `
      : `
        <button type="button" class="btn btn-record" data-action="record">Start recording</button>
        <label class="file-alt-link" for="file-input">or choose an audio file</label>
        <input type="file" id="file-input" class="visually-hidden-input" accept="audio/webm,audio/mp4,audio/aac,audio/*" aria-label="Upload a story reading" />
      `;
    bodyHtml = `
      <article class="prompt-card record-card">
        <div class="prompt-card-head">
          <span class="prompt-number">Full story reading</span>
          <span class="badge badge-empty">Not recorded</span>
        </div>
        <p class="prompt-text">Read a story out loud, clearly and warmly. You can take up to 15 minutes.</p>
        <div class="prompt-controls">
          ${fileFallback}
        </div>
      </article>
    `;
  }

  const canSubmit = !!state.blob && state.consentChecked && !uploadingNow &&
    (state.phase === "review" || state.phase === "upload_error");

  return `
    <section class="screen">
      <header class="invite-header">
        <h1>Record a story for ${escapeHtml(invite.name || "them")}</h1>
        ${relationshipLine}
        ${expiresLine}
      </header>

      <p class="instructions">
        Record one full reading (up to 15 minutes, 25 MB). When you're happy with it, send it for a parent to approve.
      </p>

      ${hardStopBanner}
      ${bodyHtml}
      ${blockedBanner}
      ${errorBanner}

      <div class="consent-row">
        <input type="checkbox" id="consent-checkbox" ${state.consentChecked ? "checked" : ""} ${uploadingNow ? "disabled" : ""} />
        <label for="consent-checkbox">I agree to record my voice for use in this app.</label>
      </div>

      <button type="button" class="btn btn-primary btn-submit" data-action="submit" ${canSubmit ? "" : "disabled"}>
        ${uploadingNow ? "Sending…" : "Send reading"}
      </button>
    </section>
  `;
}

// ---------------------------------------------------------------------------
// Recording
// ---------------------------------------------------------------------------

function clearRecordTimer() {
  if (recordTimerId !== null) {
    clearInterval(recordTimerId);
    recordTimerId = null;
  }
}

function stopTracks() {
  if (mediaStream) {
    mediaStream.getTracks().forEach((t) => t.stop());
    mediaStream = null;
  }
}

function resetRecordingState({keepConsent = true} = {}) {
  clearRecordTimer();
  if (mediaRecorder && mediaRecorder.state !== "inactive") {
    try { mediaRecorder.stop(); } catch { /* ignore */ }
  }
  mediaRecorder = null;
  stopTracks();
  recordChunks = [];
  if (state.audioUrl) URL.revokeObjectURL(state.audioUrl);
  state.blob = null;
  state.audioUrl = null;
  state.mimeType = "";
  state.durationSeconds = null;
  state.elapsedSeconds = 0;
  state.hardStopped = false;
  state.blockedMessage = "";
  state.errorMessage = "";
  if (!keepConsent) state.consentChecked = false;
}

async function startRecording() {
  if (state.phase === "recording" || uploading) return;

  if (state.micDenied) {
    render();
    return;
  }
  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    state.micDenied = true;
    state.phase = "form";
    render();
    return;
  }

  try {
    mediaStream = await navigator.mediaDevices.getUserMedia({audio: true});
    const preferred = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
      ? "audio/webm;codecs=opus"
      : MediaRecorder.isTypeSupported("audio/mp4")
        ? "audio/mp4"
        : "";
    mediaRecorder = preferred ? new MediaRecorder(mediaStream, {mimeType: preferred}) : new MediaRecorder(mediaStream);
    recordChunks = [];
    state.hardStopped = false;
    state.elapsedSeconds = 0;
    state.blockedMessage = "";
    recordStartedAt = Date.now();

    mediaRecorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) recordChunks.push(e.data);
    };

    mediaRecorder.onstop = () => {
      clearRecordTimer();
      const mimeType = normalizeMimeType(mediaRecorder?.mimeType || preferred || "audio/webm");
      const blob = new Blob(recordChunks, {type: mimeType});
      stopTracks();
      mediaRecorder = null;
      recordChunks = [];

      if (state.audioUrl) URL.revokeObjectURL(state.audioUrl);
      state.blob = blob;
      state.mimeType = mimeType;
      state.audioUrl = URL.createObjectURL(blob);
      state.durationSeconds = Math.min(
        maxDuration(),
        Math.max(1, Math.round((Date.now() - recordStartedAt) / 1000)),
      );
      state.elapsedSeconds = state.durationSeconds;

      const reason = validateBlobOrReason(blob, mimeType);
      if (reason) {
        state.blockedMessage = reason;
        state.phase = "form";
        state.blob = null;
        if (state.audioUrl) URL.revokeObjectURL(state.audioUrl);
        state.audioUrl = null;
        state.mimeType = "";
      } else {
        state.phase = "review";
      }
      render();
    };

    mediaRecorder.start(1000);
    state.phase = "recording";
    render();

    recordTimerId = setInterval(() => {
      const elapsed = Math.floor((Date.now() - recordStartedAt) / 1000);
      state.elapsedSeconds = elapsed;
      const timerEl = root.querySelector(".timer");
      if (timerEl) {
        timerEl.innerHTML = `${formatClock(elapsed)} <span class="muted small"> / ${formatClock(maxDuration())}</span>`;
      }
      if (elapsed >= maxDuration()) {
        state.hardStopped = true;
        stopRecording();
      }
    }, 250);
  } catch {
    state.micDenied = true;
    state.phase = "form";
    stopTracks();
    render();
  }
}

function stopRecording() {
  if (mediaRecorder && mediaRecorder.state === "recording") {
    mediaRecorder.stop();
  }
}

function reRecord() {
  if (uploading) return;
  resetRecordingState({keepConsent: true});
  state.phase = "form";
  render();
  startRecording();
}

function handleFileChosen(file) {
  if (!file || uploading) return;
  const mimeType = normalizeMimeType(file.type || "");
  const reason = validateBlobOrReason(file, mimeType);
  if (reason) {
    state.blockedMessage = reason;
    state.phase = "form";
    render();
    return;
  }
  if (state.audioUrl) URL.revokeObjectURL(state.audioUrl);
  state.blob = file;
  state.mimeType = mimeType;
  state.audioUrl = URL.createObjectURL(file);
  state.durationSeconds = null;
  state.elapsedSeconds = 0;
  state.hardStopped = false;
  state.blockedMessage = "";
  state.phase = "review";
  render();
}

// ---------------------------------------------------------------------------
// Upload / submit
// ---------------------------------------------------------------------------

async function handleSubmit() {
  if (uploading) return;
  if (state.phase === "recording") {
    state.blockedMessage = "Still recording — please stop before sending.";
    render();
    return;
  }
  if (!state.consentChecked) {
    state.blockedMessage = "Please check the consent box before sending.";
    render();
    return;
  }
  const reason = validateBlobOrReason(state.blob, state.mimeType);
  if (reason) {
    state.blockedMessage = reason;
    render();
    return;
  }

  state.blockedMessage = "";
  state.errorMessage = "";
  state.phase = "uploading";
  uploading = true;
  render();

  try {
    const prepared = await prepareStoryInviteUploadFn({mimeType: state.mimeType});
    const {readingId, storagePath} = prepared.data || {};
    if (!readingId || !storagePath) {
      throw new Error("Could not start upload. Please try again.");
    }

    const objectRef = storageRef(storageInstance, storagePath);
    await uploadBytes(objectRef, state.blob, {contentType: state.mimeType});

    await submitStoryInviteReadingFn({
      readingId,
      mimeType: state.mimeType,
      durationSeconds: state.durationSeconds,
    });

    if (currentToken) {
      saveStoredSession(currentToken, {
        submitted: true,
        approvalStatus: "pending",
        invite: state.invite,
      });
    }
    state.approvalStatus = "pending";
    state.phase = "status";
    uploading = false;
    render();
  } catch (err) {
    uploading = false;
    state.errorMessage = describeError(err, "Something went wrong while sending. Please try again.");
    state.phase = "upload_error";
    render();
  }
}

function describeError(err, fallback) {
  const code = err && (err.code || err?.customData?.status);
  const message = err && typeof err.message === "string" ? err.message : "";
  if (message && !message.startsWith("Firebase")) return message;
  if (typeof code === "string" && code.includes("storage/unauthorized")) {
    return "Upload was blocked. Your invite session may have expired — ask for a new link.";
  }
  if (message) return message;
  return fallback;
}

// ---------------------------------------------------------------------------
// Leave-while-uploading warning
// ---------------------------------------------------------------------------

window.addEventListener("beforeunload", (e) => {
  if (uploading || state.phase === "recording") {
    e.preventDefault();
    e.returnValue = "";
  }
});

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

root.addEventListener("click", (e) => {
  const target = e.target.closest("[data-action]");
  if (!target) return;
  const action = target.dataset.action;
  if (action === "record") startRecording();
  else if (action === "stop") stopRecording();
  else if (action === "rerecord") reRecord();
  else if (action === "submit" || action === "retry") handleSubmit();
});

root.addEventListener("change", (e) => {
  const el = e.target;
  if (el && el.id === "consent-checkbox") {
    state.consentChecked = el.checked;
    state.blockedMessage = "";
    render();
    return;
  }
  if (el && el.matches && el.matches('input[type="file"]')) {
    const file = el.files && el.files[0];
    if (file) handleFileChosen(file);
  }
});

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

function applyInviteSession(invite) {
  state.invite = {
    name: invite.name || "",
    relationship: invite.relationship || "",
    expiresAt: invite.expiresAt || "",
    maxDurationSeconds: invite.maxDurationSeconds || DEFAULT_MAX_DURATION_SECONDS,
    maxBytes: invite.maxBytes || DEFAULT_MAX_BYTES,
    allowedMimeTypes: Array.isArray(invite.allowedMimeTypes)
      ? invite.allowedMimeTypes
      : [...ALLOWED_MIMES],
  };
  state.phase = "form";
  render();
}

function applyStatus(approvalStatus, inviteMeta) {
  state.approvalStatus = approvalStatus || "pending";
  if (inviteMeta) {
    state.invite = {
      name: inviteMeta.name || "",
      relationship: inviteMeta.relationship || "",
      expiresAt: inviteMeta.expiresAt || "",
      maxDurationSeconds: DEFAULT_MAX_DURATION_SECONDS,
      maxBytes: DEFAULT_MAX_BYTES,
      allowedMimeTypes: [...ALLOWED_MIMES],
    };
  }
  state.phase = "status";
  render();
}

async function main() {
  const token = extractToken();
  if (!token) {
    state.phase = "invalid";
    state.errorMessage = "This invite link is missing or malformed.";
    render();
    return;
  }
  currentToken = token;
  render();

  let app;
  try {
    app = initializeApp(firebaseConfig);
    auth = getAuth(app);
    functionsInstance = getFunctions(app);
    storageInstance = getStorage(app);
    redeemVoiceInviteFn = httpsCallable(functionsInstance, "redeemVoiceInvite");
    prepareStoryInviteUploadFn = httpsCallable(functionsInstance, "prepareStoryInviteUpload");
    submitStoryInviteReadingFn = httpsCallable(functionsInstance, "submitStoryInviteReading");
  } catch {
    state.phase = "invalid";
    state.errorMessage = "This invite link is no longer valid.";
    render();
    return;
  }

  const stored = readStoredSession(token);

  if (stored && stored.submitted) {
    applyStatus(stored.approvalStatus || "pending", stored.invite);
    // Also refresh from server so Approved / Not approved appear once parent flow writes them.
    try {
      const result = await redeemVoiceInviteFn({token});
      const data = result.data || {};
      if (data.kind === "status") {
        applyStatus(data.approvalStatus, data);
        saveStoredSession(token, {
          submitted: true,
          approvalStatus: data.approvalStatus,
          invite: {name: data.name, relationship: data.relationship},
        });
      }
    } catch {
      // Keep local pending status if network/status lookup fails.
    }
    return;
  }

  if (stored && stored.customToken && stored.invite && !stored.submitted) {
    const restoredUser = await waitForAuthInit(auth);
    let liveUser = restoredUser && restoredUser.uid === stored.uid && (await hasLiveInviteClaims(restoredUser))
      ? restoredUser
      : null;
    if (!liveUser) {
      try {
        const cred = await signInWithCustomToken(auth, stored.customToken);
        if (await hasLiveInviteClaims(cred.user)) liveUser = cred.user;
      } catch {
        liveUser = null;
      }
    }
    if (liveUser) {
      applyInviteSession(stored.invite);
      return;
    }
    clearStoredSession(token);
  }

  try {
    const result = await redeemVoiceInviteFn({token});
    const data = result.data || {};

    if (data.kind === "status") {
      applyStatus(data.approvalStatus, data);
      saveStoredSession(token, {
        submitted: true,
        approvalStatus: data.approvalStatus,
        invite: {name: data.name, relationship: data.relationship},
      });
      return;
    }

    // Backward-compat: older servers may omit kind but still return customToken.
    const customToken = data.customToken;
    if (!customToken) {
      throw new Error("invalid");
    }

    const cred = await signInWithCustomToken(auth, customToken);
    const invite = {
      name: data.name || "",
      relationship: data.relationship || "",
      expiresAt: data.expiresAt || "",
      maxDurationSeconds: data.maxDurationSeconds || DEFAULT_MAX_DURATION_SECONDS,
      maxBytes: data.maxBytes || DEFAULT_MAX_BYTES,
      allowedMimeTypes: Array.isArray(data.allowedMimeTypes)
        ? data.allowedMimeTypes
        : [...ALLOWED_MIMES],
    };
    saveStoredSession(token, {
      customToken,
      uid: cred.user.uid,
      invite,
      submitted: false,
    });
    applyInviteSession(invite);
  } catch {
    state.phase = "invalid";
    state.errorMessage = "This invite link is no longer valid.";
    render();
  }
}

main().catch(() => {
  state.phase = "invalid";
  state.errorMessage = "This invite link is no longer valid.";
  render();
});
