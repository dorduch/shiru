# Recording Feature — Design Spec

## Context

Shiru is a DIY audio player for kids. Parents currently add audio content by importing files via file picker. This feature adds the ability to **record audio directly** within the app — enabling parents to record bedtime stories, songs, or personal messages without needing external recording tools.

## Requirements

- **Who:** Parents only (behind PIN gate)
- **Where:** Inline within ParentEditScreen, replacing the current audio file picker
- **Capabilities:** Record with pause/resume, preview before saving
- **Output:** Audio file saved to app documents directory, same as imported files

## Design

### UI States

The audio section in ParentEditScreen cycles through 3 states:

#### State 1: Audio Source Selection
Two side-by-side cards replace the current single "Tap to select audio file" button:
- **Pick File** (gray, dashed border) — opens existing `FilePicker` flow
- **Record** (red gradient, mic icon) — transitions to State 2

If a card is being edited and already has audio, show the current audio info with options to re-pick or re-record instead.

#### State 2: Recording in Progress
- Red pulsing dot + "Recording" label + elapsed timer (MM:SS format)
- Waveform visualization (animated bars showing audio amplitude)
- **Pause** button (dark gray) — pauses recording, label changes to "Resume"
- **Stop** button (red) — stops recording, transitions to State 3
- **Cancel** (text button or back arrow) — discards recording, returns to State 1

#### State 3: Preview & Confirm
- Green dot + "Recorded" label + duration display
- Static waveform visualization of the recorded audio
- **Play** button (green) — plays back the recording for preview. Toggles to Pause during playback
- **Re-record** button (dark gray) — discards recording, returns to State 2
- The existing green **Save** button in the header saves the card with the recorded audio (no extra confirmation)

### Audio Recording Architecture

#### Recording Service (`lib/services/recording_service.dart`)
New service following the same pattern as `AudioService`:
- Wraps a recording package (e.g., `record` package)
- Manages recorder lifecycle: initialize, start, pause, resume, stop, dispose
- Records to a temporary file in the app's temp directory
- Returns the recorded file path on completion
- Provides a stream of recording state (recording, paused, stopped), duration, and amplitude (for waveform visualization)
- Stores amplitude samples during recording for static waveform display in preview state
- Cleans up temp files after successful copy to documents directory

#### Recording Provider (`lib/providers/recording_provider.dart`)
Riverpod provider following existing patterns:
- `recordingServiceProvider` — singleton service instance
- `recordingStateProvider` — current state enum (idle, recording, paused, stopped)
- `recordingDurationProvider` — elapsed time stream

#### Integration with Existing Audio Pipeline
On save, the recorded file follows the **exact same path** as imported files:
1. Recording saved to temp file (e.g., `/tmp/recording_uuid.m4a`)
2. `_save()` in ParentEditScreen copies it to app documents dir with UUID filename
3. Path stored in `AudioCard.audioPath` — no schema changes needed
4. Playback works identically via existing `AudioService.playCard()`

### Recording Widget (`lib/ui/widgets/audio_recorder_widget.dart`)
Stateful widget managing the 3 UI states:
- Uses `recordingServiceProvider` for recording operations
- Uses existing `audioPlayerProvider` for preview playback
- Exposes an `onAudioSelected(String path)` callback to ParentEditScreen
- Handles microphone permission requests via `permission_handler`

### Permissions
- Request microphone permission on first "Record" tap
- Show explanation dialog if denied
- Handle "permanently denied" by directing to system settings
- iOS: Add `NSMicrophoneUsageDescription` to Info.plist
- Android: Add `RECORD_AUDIO` permission to AndroidManifest.xml

### File Format
- Record in AAC/M4A format (good quality, small size, natively supported by `just_audio`)
- Sample rate: 44100 Hz
- No format conversion needed — `just_audio` plays M4A files via `setFilePath()`

## Dependencies

New packages to add to `pubspec.yaml`:
- **`record`** — cross-platform audio recording (iOS + Android)
- **`permission_handler`** — microphone permission management

## Data Model

**No changes to `AudioCard` model or database schema.** Recorded files are stored identically to imported files — as local files with paths in `audioPath`.

## Files to Create/Modify

### New Files
- `lib/services/recording_service.dart` — recording logic
- `lib/providers/recording_provider.dart` — Riverpod state
- `lib/ui/widgets/audio_recorder_widget.dart` — inline recorder UI

### Modified Files
- `app/pubspec.yaml` — add `record` and `permission_handler` dependencies
- `lib/ui/parent_edit_screen.dart` — replace audio picker with source selection + recorder widget
- `ios/Runner/Info.plist` — add `NSMicrophoneUsageDescription`
- `android/app/src/main/AndroidManifest.xml` — add `RECORD_AUDIO` permission

## Edge Cases

- **Incoming call during recording:** Pause recording, resume when call ends (handled by OS/record package)
- **App backgrounded during recording:** Stop recording, preserve what was captured
- **Storage full:** Show error toast, don't save partial file
- **Permission denied:** Show explanation, offer to open settings
- **Existing audio on card edit:** Show current audio info with option to replace via pick or record

## Verification

1. Create a new card → tap Record → grant mic permission → record audio with pause/resume → stop → preview playback → save card
2. Verify the card plays correctly from KidHomeScreen
3. Edit an existing card → re-record audio → verify old file replaced
4. Test permission denied flow
5. Test on both iOS and Android
6. Run `flutter analyze` — no new warnings
