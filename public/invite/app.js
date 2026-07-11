// Voice invite recording page — Task 7.
// See docs/superpowers/specs/2026-07-11-voice-invite-implementation-plan.md
// for the pinned request/response contracts this file codes against
// (`redeemVoiceInvite`, `uploadVoiceInviteSample`, `submitVoiceInvite`).
//
// No framework, no bundler. Firebase JS SDK v9 modular, loaded from the
// gstatic CDN, pinned to a specific 10.x release.

import {
  initializeApp,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import {
  getAuth,
  signInWithCustomToken,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import {
  getFunctions,
  httpsCallable,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-functions.js";

// ---------------------------------------------------------------------------
// Firebase web config
// ---------------------------------------------------------------------------
// Project `shiru-bcdd2` has Android + iOS app configs (see
// app/lib/firebase_options.dart, app/ios/Runner/GoogleService-Info.plist,
// app/android/app/google-services.json) but NO registered Web app as of this
// writing, so there is no web-specific apiKey/appId to pull.
//
// projectId / messagingSenderId / storageBucket are project-wide and safe to
// reuse. authDomain follows the standard `<projectId>.firebaseapp.com`
// pattern. apiKey and appId are NOT safe to borrow from the Android/iOS
// configs — those keys are platform-restricted (Android by package name +
// SHA-1 fingerprint, iOS by bundle ID) and will be rejected when called from
// a browser origin.
//
// TODO(web-app-config): Register a Web app for shiru-bcdd2 in the Firebase
// console (Project settings -> Your apps -> Add app -> Web), then replace
// the two placeholders below with the real values before deploying this
// page. Do not ship with placeholders.
const firebaseConfig = {
  apiKey: "TODO-REPLACE-WITH-WEB-API-KEY",
  authDomain: "shiru-bcdd2.firebaseapp.com",
  projectId: "shiru-bcdd2",
  storageBucket: "shiru-bcdd2.firebasestorage.app",
  messagingSenderId: "310525193859",
  appId: "TODO-REPLACE-WITH-WEB-APP-ID",
};

const NUM_PROMPTS = 5;
const MAX_UPLOAD_BYTES = 8 * 1024 * 1024; // server rejects payloads decoding to >8MB

const root = document.getElementById("app");

/** @type {{
 *  phase: "redeeming"|"invalid"|"form"|"submitting"|"submit_error"|"success",
 *  errorMessage: string,
 *  invite: null | { name: string, relationship: string, prompts: {label:string,text:string}[], expiresAt: string },
 *  prompts: any[],
 *  consentChecked: boolean,
 *  micDenied: boolean,
 *  submitBlockedMessage: string,
 * }}
 */
const state = {
  phase: "redeeming",
  errorMessage: "",
  invite: null,
  prompts: [],
  consentChecked: false,
  micDenied: false,
  submitBlockedMessage: "",
};

let auth = null;
let functionsInstance = null;
let redeemVoiceInviteFn = null;
let uploadVoiceInviteSampleFn = null;
let submitVoiceInviteFn = null;

function extractToken() {
  // Expect "/invite/<token>" (optionally with a trailing slash).
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

function normalizeMimeType(mimeType) {
  // MediaRecorder typically reports "audio/webm;codecs=opus" — the server
  // maps extension -> content-type from a bare mime type, so strip params.
  return (mimeType || "").split(";")[0].trim();
}

function blobToBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = String(reader.result || "");
      const commaIdx = dataUrl.indexOf(",");
      resolve(commaIdx >= 0 ? dataUrl.slice(commaIdx + 1) : dataUrl);
    };
    reader.onerror = () => reject(reader.error || new Error("Failed to read recording."));
    reader.readAsDataURL(blob);
  });
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
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
    case "success":
      root.innerHTML = renderSuccess();
      break;
    case "form":
    case "submitting":
    case "submit_error":
      root.innerHTML = renderForm();
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

function renderSuccess() {
  return `
    <section class="screen screen-center">
      <div class="success-check" aria-hidden="true">&#10003;</div>
      <h1>Thank you!</h1>
      <p>Your voice is being prepared. You can close this page now.</p>
    </section>
  `;
}

function renderForm() {
  const invite = state.invite || { name: "", relationship: "", prompts: [] };
  const allRecorded = state.prompts.length === NUM_PROMPTS &&
    state.prompts.every((p) => p.status === "recorded" || p.status === "uploaded" || p.status === "uploading");
  const submitDisabled = !allRecorded || !state.consentChecked || state.phase === "submitting";
  const submitting = state.phase === "submitting";

  const cardsHtml = state.prompts.map((p, idx) => renderPromptCard(p, idx)).join("");

  const relationshipLine = invite.relationship
    ? `<p class="header-sub">Relationship: ${escapeHtml(invite.relationship)}</p>`
    : "";

  const expiresLine = invite.expiresAt
    ? `<p class="muted small">This link expires ${escapeHtml(formatExpiry(invite.expiresAt))}.</p>`
    : "";

  const blockedBanner = state.submitBlockedMessage
    ? `<div class="banner banner-warn" role="alert">${escapeHtml(state.submitBlockedMessage)}</div>`
    : "";

  const errorBanner = state.phase === "submit_error"
    ? `
      <div class="banner banner-error" role="alert">
        <p>${escapeHtml(state.errorMessage || "Something went wrong while submitting. Please try again.")}</p>
        <button type="button" class="btn btn-secondary" data-action="retry">Try again</button>
      </div>
    `
    : "";

  return `
    <section class="screen">
      <header class="invite-header">
        <h1>Record your voice for ${escapeHtml(invite.name || "them")}'s stories</h1>
        ${relationshipLine}
        ${expiresLine}
      </header>

      <p class="instructions">
        Read each line below out loud, clearly and naturally. You can re-record
        as many times as you like before submitting.
      </p>

      <div class="prompt-list">
        ${cardsHtml}
      </div>

      ${blockedBanner}
      ${errorBanner}

      <div class="consent-row">
        <input type="checkbox" id="consent-checkbox" ${state.consentChecked ? "checked" : ""} />
        <label for="consent-checkbox">I agree to record my voice for use in this app.</label>
      </div>

      <button type="button" class="btn btn-primary btn-submit" data-action="submit" ${submitDisabled ? "disabled" : ""}>
        ${submitting ? "Submitting…" : "Submit my recordings"}
      </button>
    </section>
  `;
}

function formatExpiry(iso) {
  try {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return "soon";
    return `on ${d.toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" })}`;
  } catch {
    return "soon";
  }
}

function renderPromptCard(p, idx) {
  const num = idx + 1;
  const isRecording = p.status === "recording";
  const isRecorded = p.status === "recorded" || p.status === "uploaded" || p.status === "uploading";
  const isUploaded = p.status === "uploaded";
  const isUploading = p.status === "uploading";
  const showFileFallback = p.micFailed || state.micDenied;

  let statusBadge = "";
  if (isUploaded) statusBadge = `<span class="badge badge-done">Uploaded &#10003;</span>`;
  else if (isUploading) statusBadge = `<span class="badge badge-progress">Uploading…</span>`;
  else if (isRecorded) statusBadge = `<span class="badge badge-recorded">Recorded &#10003;</span>`;
  else if (isRecording) statusBadge = `<span class="badge badge-live">Recording…</span>`;
  else statusBadge = `<span class="badge badge-empty">Not recorded</span>`;

  let controlsHtml = "";
  if (isRecording) {
    controlsHtml = `<button type="button" class="btn btn-stop" data-action="stop" data-idx="${idx}">Stop recording</button>`;
  } else if (isRecorded) {
    const audioSrc = p.audioUrl ? `<audio class="playback" controls src="${p.audioUrl}"></audio>` : "";
    const disableRerecord = isUploading ? "disabled" : "";
    controlsHtml = `
      ${audioSrc}
      <button type="button" class="btn btn-secondary" data-action="rerecord" data-idx="${idx}" ${disableRerecord}>
        Re-record
      </button>
    `;
  } else if (showFileFallback) {
    controlsHtml = `
      <p class="mic-fallback-note">
        Microphone isn't available. Choose an audio file instead.
      </p>
      <label class="btn btn-secondary file-label" for="file-input-${idx}">Choose audio file</label>
      <input
        type="file"
        id="file-input-${idx}"
        class="visually-hidden-input"
        accept="audio/*"
        data-idx="${idx}"
        aria-label="Upload recording for prompt ${num}"
      />
    `;
  } else {
    controlsHtml = `
      <button type="button" class="btn btn-record" data-action="record" data-idx="${idx}">
        Record
      </button>
      <label class="file-alt-link" for="file-input-${idx}">or choose an audio file</label>
      <input
        type="file"
        id="file-input-${idx}"
        class="visually-hidden-input"
        accept="audio/*"
        data-idx="${idx}"
        aria-label="Upload recording for prompt ${num}"
      />
    `;
  }

  const uploadErr = p.uploadError
    ? `<p class="upload-error" role="alert">${escapeHtml(p.uploadError)}</p>`
    : "";

  return `
    <article class="prompt-card" data-card-idx="${idx}">
      <div class="prompt-card-head">
        <span class="prompt-number">${num} / ${NUM_PROMPTS}</span>
        ${statusBadge}
      </div>
      <p class="prompt-label">${escapeHtml(p.label)}</p>
      <p class="prompt-text">&ldquo;${escapeHtml(p.text)}&rdquo;</p>
      <div class="prompt-controls">
        ${controlsHtml}
      </div>
      ${uploadErr}
    </article>
  `;
}

// ---------------------------------------------------------------------------
// Recording logic
// ---------------------------------------------------------------------------

async function startRecording(idx) {
  const p = state.prompts[idx];
  if (!p || p.status === "recording") return;

  if (state.micDenied || p.micFailed) {
    // Already known to be unavailable — just re-render to surface the file
    // fallback rather than re-prompting for permission.
    p.micFailed = true;
    render();
    return;
  }

  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    p.micFailed = true;
    state.micDenied = true;
    render();
    return;
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const recorder = new MediaRecorder(stream);
    const chunks = [];

    p.stream = stream;
    p.recorder = recorder;

    recorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) chunks.push(e.data);
    };

    recorder.onstop = () => {
      const mimeType = recorder.mimeType || "audio/webm";
      const blob = new Blob(chunks, { type: mimeType });
      if (p.audioUrl) URL.revokeObjectURL(p.audioUrl);
      p.blob = blob;
      p.mimeType = normalizeMimeType(mimeType);
      p.audioUrl = URL.createObjectURL(blob);
      p.status = "recorded";
      p.source = "record";
      p.recorder = null;
      stream.getTracks().forEach((t) => t.stop());
      p.stream = null;
      render();
    };

    recorder.start();
    p.status = "recording";
    render();
  } catch (err) {
    p.micFailed = true;
    state.micDenied = true;
    render();
  }
}

function stopRecording(idx) {
  const p = state.prompts[idx];
  if (p && p.recorder && p.status === "recording") {
    p.recorder.stop();
  }
}

function reRecord(idx) {
  const p = state.prompts[idx];
  if (!p || p.status === "uploading") return;
  if (p.audioUrl) URL.revokeObjectURL(p.audioUrl);
  p.blob = null;
  p.audioUrl = null;
  p.mimeType = "";
  p.status = "idle";
  p.source = null;
  p.uploadError = "";
  render();
  startRecording(idx);
}

function handleFileChosen(idx, file) {
  const p = state.prompts[idx];
  if (!p) return;
  if (p.audioUrl) URL.revokeObjectURL(p.audioUrl);
  p.blob = file;
  p.mimeType = normalizeMimeType(file.type || "audio/mp4");
  p.audioUrl = URL.createObjectURL(file);
  p.status = "recorded";
  p.source = "file";
  p.uploadError = "";
  render();
}

// ---------------------------------------------------------------------------
// Submit flow
// ---------------------------------------------------------------------------

async function handleSubmit() {
  if (state.phase === "submitting") return;

  // Edge case: still recording when submit pressed.
  const activeIdx = state.prompts.findIndex((p) => p.status === "recording");
  if (activeIdx !== -1) {
    state.submitBlockedMessage = `Prompt ${activeIdx + 1} is still recording — please stop it before submitting.`;
    render();
    return;
  }

  // Edge case: no mic + no file chosen for one or more prompts.
  const missingIdx = state.prompts.findIndex((p) => !p.blob);
  if (missingIdx !== -1) {
    state.submitBlockedMessage = `Prompt ${missingIdx + 1} still needs a recording or an audio file.`;
    render();
    return;
  }

  if (!state.consentChecked) {
    state.submitBlockedMessage = "Please check the consent box before submitting.";
    render();
    return;
  }

  state.submitBlockedMessage = "";
  state.errorMessage = "";
  state.phase = "submitting";
  render();

  try {
    for (let idx = 0; idx < NUM_PROMPTS; idx++) {
      const p = state.prompts[idx];
      p.status = "uploading";
      p.uploadError = "";
      render();

      if (p.blob.size > MAX_UPLOAD_BYTES) {
        throw new Error(`Prompt ${idx + 1}'s recording is too large. Please re-record a shorter clip.`);
      }

      const dataBase64 = await blobToBase64(p.blob);
      await uploadVoiceInviteSampleFn({
        idx,
        dataBase64,
        mimeType: p.mimeType || "audio/webm",
      });

      p.status = "uploaded";
      render();
    }

    await submitVoiceInviteFn({});

    state.phase = "success";
    render();
  } catch (err) {
    state.errorMessage = describeError(err, "Something went wrong while submitting. Please try again.");
    state.phase = "submit_error";
    // Reset any prompt stuck mid-upload back to "recorded" so retry can
    // re-attempt it (uploads are idempotent per idx).
    state.prompts.forEach((p) => {
      if (p.status === "uploading") p.status = "recorded";
    });
    render();
  }
}

function describeError(err, fallback) {
  if (err && typeof err.message === "string" && err.message.trim()) {
    return err.message;
  }
  return fallback;
}

// ---------------------------------------------------------------------------
// Event delegation
// ---------------------------------------------------------------------------

root.addEventListener("click", (e) => {
  const target = e.target.closest("[data-action]");
  if (!target) return;
  const action = target.dataset.action;
  const idx = target.dataset.idx !== undefined ? Number(target.dataset.idx) : null;

  if (action === "record") startRecording(idx);
  else if (action === "stop") stopRecording(idx);
  else if (action === "rerecord") reRecord(idx);
  else if (action === "submit") handleSubmit();
  else if (action === "retry") handleSubmit();
});

root.addEventListener("change", (e) => {
  const el = e.target;
  if (el && el.id === "consent-checkbox") {
    state.consentChecked = el.checked;
    state.submitBlockedMessage = "";
    render();
    return;
  }
  if (el && el.matches && el.matches('input[type="file"]')) {
    const idx = Number(el.dataset.idx);
    const file = el.files && el.files[0];
    if (file) handleFileChosen(idx, file);
  }
});

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

async function main() {
  const token = extractToken();

  if (!token) {
    state.phase = "invalid";
    state.errorMessage = "This invite link is missing or malformed.";
    render();
    return;
  }

  render(); // show "redeeming…"

  let app;
  try {
    app = initializeApp(firebaseConfig);
    auth = getAuth(app);
    // No App Check on this page by design: redeemVoiceInvite,
    // uploadVoiceInviteSample and submitVoiceInvite are all
    // enforceAppCheck:false invite-claim-gated callables (see the pinned
    // contracts doc), so there is nothing to attach here.
    functionsInstance = getFunctions(app);
    redeemVoiceInviteFn = httpsCallable(functionsInstance, "redeemVoiceInvite");
    uploadVoiceInviteSampleFn = httpsCallable(functionsInstance, "uploadVoiceInviteSample");
    submitVoiceInviteFn = httpsCallable(functionsInstance, "submitVoiceInvite");
  } catch (err) {
    state.phase = "invalid";
    state.errorMessage = "This invite link is no longer valid.";
    render();
    return;
  }

  try {
    const result = await redeemVoiceInviteFn({ token });
    const data = result.data || {};

    await signInWithCustomToken(auth, data.customToken);

    state.invite = {
      name: data.name || "",
      relationship: data.relationship || "",
      prompts: Array.isArray(data.prompts) ? data.prompts : [],
      expiresAt: data.expiresAt || "",
    };
    state.prompts = state.invite.prompts.slice(0, NUM_PROMPTS).map((pr) => ({
      label: pr.label || "",
      text: pr.text || "",
      status: "idle", // idle | recording | recorded | uploading | uploaded
      blob: null,
      mimeType: "",
      audioUrl: null,
      recorder: null,
      stream: null,
      source: null,
      micFailed: false,
      uploadError: "",
    }));
    // Pad defensively if the server ever returns fewer/more than 5.
    while (state.prompts.length < NUM_PROMPTS) {
      state.prompts.push({
        label: `Prompt ${state.prompts.length + 1}`,
        text: "",
        status: "idle",
        blob: null,
        mimeType: "",
        audioUrl: null,
        recorder: null,
        stream: null,
        source: null,
        micFailed: false,
        uploadError: "",
      });
    }

    state.phase = "form";
    render();
  } catch (err) {
    state.phase = "invalid";
    state.errorMessage = "This invite link is no longer valid.";
    render();
  }
}

main().catch(() => {
  // Last-resort safety net so nothing throws uncaught to the console.
  state.phase = "invalid";
  state.errorMessage = "This invite link is no longer valid.";
  render();
});
