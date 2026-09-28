/* invite-1b record */
const RR = globalThis.__RR;
const {
  ALLOWED_MIMES,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_DURATION_SECONDS,
  SESSION_STORAGE_PREFIX,
  clearRecordTimer,
  clearStoredSession,
  describeMimeBlock,
  describeSizeBlock,
  escapeHtml,
  extractToken,
  firebaseConfig,
  formatClock,
  formatExpiry,
  hasLiveInviteClaims,
  isMimeAllowed,
  maxBytes,
  maxDuration,
  normalizeMimeType,
  readStoredSession,
  render,
  renderCapture,
  renderInvalid,
  renderRedeeming,
  renderStatus,
  resetRecordingState,
  root,
  saveStoredSession,
  sessionStorageKey,
  state,
  stopTracks,
  validateBlobOrReason,
  waitForAuthInit,
} = RR;

async function startRecording() {
  if (state.phase === "recording" || RR.uploading) return;

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
    RR.mediaStream = await navigator.mediaDevices.getUserMedia({audio: true});
    const preferred = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
      ? "audio/webm;codecs=opus"
      : MediaRecorder.isTypeSupported("audio/mp4")
        ? "audio/mp4"
        : "";
    RR.mediaRecorder = preferred ? new MediaRecorder(RR.mediaStream, {mimeType: preferred}) : new MediaRecorder(RR.mediaStream);
    RR.recordChunks = [];
    state.hardStopped = false;
    state.elapsedSeconds = 0;
    state.blockedMessage = "";
    RR.recordStartedAt = Date.now();

    RR.mediaRecorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) RR.recordChunks.push(e.data);
    };

    RR.mediaRecorder.onstop = () => {
      clearRecordTimer();
      const mimeType = normalizeMimeType(RR.mediaRecorder?.mimeType || preferred || "audio/webm");
      const blob = new Blob(RR.recordChunks, {type: mimeType});
      stopTracks();
      RR.mediaRecorder = null;
      RR.recordChunks = [];

      if (state.audioUrl) URL.revokeObjectURL(state.audioUrl);
      state.blob = blob;
      state.mimeType = mimeType;
      state.audioUrl = URL.createObjectURL(blob);
      state.durationSeconds = Math.min(
        maxDuration(),
        Math.max(1, Math.round((Date.now() - RR.recordStartedAt) / 1000)),
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

    RR.mediaRecorder.start(1000);
    state.phase = "recording";
    render();

    RR.recordTimerId = setInterval(() => {
      const elapsed = Math.floor((Date.now() - RR.recordStartedAt) / 1000);
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
  if (RR.mediaRecorder && RR.mediaRecorder.state === "recording") {
    RR.mediaRecorder.stop();
  }
}

function reRecord() {
  if (RR.uploading) return;
  resetRecordingState({keepConsent: true});
  state.phase = "form";
  render();
  startRecording();
}

function handleFileChosen(file) {
  if (!file || RR.uploading) return;
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


Object.assign(RR, {
  handleFileChosen,
  reRecord,
  startRecording,
  stopRecording
});
Object.assign(globalThis, {
  handleFileChosen,
  reRecord,
  startRecording,
  stopRecording
});
