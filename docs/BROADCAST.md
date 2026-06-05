# Broadcast Extension — System Guide

This document is written for the next developer or AI agent working on this codebase.
It explains what the broadcast system does, what bugs existed, what was changed and why,
and how every piece fits together.

---

## 1. What the app does (big picture)

**don-ten-team** is a parental-guidance app called **Kiddly**. A parent sets up a
"screen session" for a child. During the session:

1. The child's device is partially locked (ManagedSettings shields unwanted apps).
2. A **ReplayKit broadcast extension** (`ScreenRecorderExtension`) records the device
   screen at 1 fps to an MP4 in a shared App Group.
3. When the session ends, the main app runs an ML pipeline
   (`PipelineOrchestrator`) on the recording: frame classification (MobileCLIP),
   OCR / handle extraction, Whisper transcription, LLM summary.
4. Results are shown on the `SessionResultView` for the parent.

The broadcast extension is an iOS **app extension** — it runs in a separate process
sandboxed from the main app. Communication happens via:
- **App Group UserDefaults** (shared key-value store)
- **Darwin notifications** (low-level IPC, `CFNotificationCenter`)
- A shared MP4 file moved into the App Group container on session end

---

## 2. Bugs that existed (and are now fixed)

### Bug 1 — Wired external monitor broke recording

**Symptom:** Connecting a USB-C / HDMI external display mid-session caused the
broadcast to silently stop recording (no file, or a corrupt / zero-byte file).

**Root cause:** `SampleHandler.processSampleBuffer` configured `AVAssetWriterInput`
with the width × height of the **first** video frame received from ReplayKit. When an
external monitor was connected, ReplayKit changed the resolution of subsequent frames
(e.g. 1170×2532 → 2560×1440 for a 4K display). Appending these mismatched buffers to
a fixed-size `AVAssetWriterInput` caused the writer to enter `.failed` state. All
subsequent appends were silently dropped.

**Fix:** `BroadcastFrameEncoder` locks the encode size on the first frame (≤720 px on
the long edge, even dimensions required by H.264). All subsequent frames — regardless
of incoming ReplayKit resolution — are **scaled** to that locked size before appending.
`AVAssetWriterInputPixelBufferAdaptor` wraps the input so pixel buffers are appended
directly rather than via `CMSampleBuffer`. Dimension changes are logged to
`extension_debug.log` but do not affect the writer.

### Bug 2 — Broadcast couldn't be stopped (session end hung)

**Symptom:** After "End Session", the iOS status bar broadcast indicator stayed active
indefinitely. The app appeared frozen waiting for analysis to start.

**Root cause:** The Darwin stop path called `finalizeAndSave()` then
`finishBroadcastWithError()`. `finalizeAndSave()` blocked the Darwin callback thread
with `DispatchSemaphore.wait(timeout: .now() + 10)` waiting for `writer.finishWriting`.
In some conditions (especially after a wired-display writer failure) `finishWriting`
never completed, or the completion handler was dispatched back to the same queue,
causing a deadlock. The `finishBroadcastWithError` call after the 10-second timeout
was too late.

Additionally, the Darwin observer and the GCD auto-stop timer each called
`finalizeAndSave()` independently, risking a double-finalize race.

**Fix:** The Darwin observer and GCD timer now call only `triggerStop()`, which calls
`finishBroadcastWithError()` with an idempotent `stopRequested` guard. ReplayKit then
calls `broadcastFinished()` (stops delivering sample buffers). All finalization
(semaphore wait, file move, `recordingReady` notification) happens inside
`broadcastFinished()`, which is the correct and only place to block — iOS keeps the
extension process alive until this method returns.

### Bug 3 — Slow broadcast start

**Symptom:** Several seconds elapsed between the user tapping the broadcast button and
recording actually starting.

**Root cause:** `AVAssetWriter` was created only when the first video frame arrived.
Extension cold start + waiting for the first frame + `startWriting` all serialized
added noticeable latency.

**Fix:** `AVAssetWriter` is now created in `broadcastStarted` (immediately on extension
launch). The writer inputs (`AVAssetWriterInput` + `AVAssetWriterInputPixelBufferAdaptor`)
are still added on the first video frame (required by AVFoundation before `startWriting`),
but the writer object itself is ready so `startWriting` fires on the very first frame.

### Bug 4 — `appGroupID` was duplicated / no shared constants

**Symptom:** `SampleHandler.swift` had its own copy of the app-group-ID derivation
logic. Any drift between it and `SigningConfig` would cause the extension to write to a
different App Group than the main app reads from.

**Fix:** `BroadcastShared/BroadcastAppGroup.swift` is the single source of truth. Both
targets compile it. `SigningConfig.appGroupID` now delegates to
`BroadcastAppGroup.identifier`.

---

## 3. File map — every file that matters for broadcast

### `BroadcastShared/` — repo root, compiled into both targets

This folder is a `PBXFileSystemSynchronizedRootGroup` added to both the `team-10-c3`
and `ScreenRecorderExtension` targets in `project.pbxproj` (UUID `8FBCA0012FCA0000001AF248`).

| File | What it does |
|------|-------------|
| `BroadcastAppGroup.swift` | `BroadcastAppGroup.identifier` — computes `group.<prefix>.don-ten-team.shared` from `Bundle.main.bundleIdentifier` at runtime. Works correctly from both the main app and the extension because both bundle IDs start with the same prefix. |
| `BroadcastStorageKeys.swift` | String constants for all App Group UserDefaults keys: `latestRecordingPath`, `targetSessionDurationMinutes`, `broadcastActive`, and the log filename `extensionDebugLog`. |
| `BroadcastNotifications.swift` | `CFNotificationName` values for `recordingReady` (extension → app) and `stopBroadcast` (app → extension). Derived from `BroadcastAppGroup.identifier` so they are always namespace-unique. |
| `BroadcastFrameEncoder.swift` | Locks encode size on first frame call, scales every `CVPixelBuffer` to that size using `CIContext`. Key API: `lockedEncodeSize(sourceWidth:sourceHeight:)`, `scale(pixelBuffer:to:pool:)`, `sourceDimensionsChanged(...)` for logging. |
| `BroadcastExtensionLog.swift` | `append(_:)` / `reset()` / `read()` for `extension_debug.log` in the App Group container. The extension calls `append` for every significant event; the main app can call `read()` to surface diagnostics. |

### `ScreenRecorderExtension/SampleHandler.swift`

The entire extension lives in this single file. Key sections:

| Section | What it does |
|---------|-------------|
| `broadcastStarted` | Resets log, registers Darwin observer, sets `broadcastActive = true`, writes `LatestRecordingPath` to App Group, schedules auto-stop GCD timer, creates `AVAssetWriter` to a temp file. |
| `processSampleBuffer` | On first video frame: calls `configureVideoInputs` which creates `AVAssetWriterInput` + `AVAssetWriterInputPixelBufferAdaptor` and calls `startWriting` / `startSession`. On subsequent frames: rate-limits to 1 fps, logs dimension changes, scales via `BroadcastFrameEncoder`, appends via adaptor. |
| `broadcastFinished` | Removes Darwin observer, cancels timer, marks inputs finished, calls `writer.finishWriting` with a `DispatchSemaphore` to block until done, then `moveRecordingToAppGroup()`. **This is the only place finalization happens.** |
| `triggerStop(reason:)` | Idempotent (`stopRequested` flag). Calls `finishBroadcastWithError` which triggers `broadcastFinished`. |
| `registerDarwinObserver` / `removeDarwinObserver` | Proper `Unmanaged.passRetained` / `.release` balance to avoid memory leaks. The observer pointer is stored in `darwinObserverToken`. |
| `moveRecordingToAppGroup` | Moves temp MP4 from `FileManager.temporaryDirectory` to App Group container, updates `LatestRecordingPath`, posts `recordingReady` Darwin notification. |

**Why temp directory?** `AVAssetWriter` (via `mediaserverd`) cannot write directly to
App Group containers on some devices due to sandbox restrictions. The extension writes
to its own temp directory first, then moves the file after `finishWriting`.

### `team-10-c3/Shared/BroadcastConstants.swift`

Lives only in the main app target. Acts as a bridge so the rest of the app doesn't
need to import `BroadcastShared` types directly:
- `appGroupID` → `SigningConfig.appGroupID` → `BroadcastAppGroup.identifier`
- `recordingReadyNotification` → `BroadcastNotifications.recordingReady`
- `stopBroadcastNotification` → `BroadcastNotifications.stopBroadcast`
- `latestRecordingPathKey` → `BroadcastStorageKeys.latestRecordingPath`
- `targetSessionDurationKey` → `BroadcastStorageKeys.targetSessionDurationMinutes`

### `team-10-c3/Shared/SigningConfig.swift`

Provides bundle-ID-derived values needed by the main app. `appGroupID` now delegates
to `BroadcastAppGroup.identifier` (single source of truth).

### `team-10-c3/Services/ScreenTime/RecordingManager.swift`

`@MainActor` singleton. Key methods:

| Method | What it does |
|--------|-------------|
| `setSessionDuration(minutes:)` | Writes `targetSessionDurationMinutes` to App Group. Read by the extension's auto-stop timer. |
| `clearSessionDuration()` | Removes the key so the extension runs without a timer. |
| `postStopBroadcast()` | Posts the Darwin `stopBroadcast` notification → extension calls `triggerStop`. |
| `waitForBroadcastEnded(timeout:)` | Polls `UIScreen.main.isCaptured` every 500 ms until false or timeout (15 s default). Called by `KidSessionViewModel` before starting analysis to avoid reading the recording file before the extension has finished writing. |
| `findLatestRecordingURL()` | Checks `LatestRecordingPath` first, then falls back to the most recent MP4 in the App Group container. |

### `team-10-c3/Features/KidSession/KidSessionViewModel.swift`

Orchestrates the kid session. Relevant section in `runSessionAnalysis()`:

```
1. if UIScreen.main.isCaptured:
       await RecordingManager.shared.waitForBroadcastEnded(timeout: 15)
   ↳ waits for extension to stop (isCaptured → false)

2. RecordingReadyBridge.startListening()
   await waitForRecordingReady(timeoutSeconds: 10)
   ↳ waits for Darwin recordingReady notification from extension

3. await executePipeline()
   ↳ runs ML pipeline on the recording
```

### `team-10-c3.xcodeproj/project.pbxproj`

Changes made (search for `8FBCA0012FCA0000001AF248` to find them):
- New `PBXFileSystemSynchronizedRootGroup` entry for `BroadcastShared`
- Added to `children` of the root project group
- Added to `fileSystemSynchronizedGroups` of `team-10-c3` target
- Added to `fileSystemSynchronizedGroups` of `ScreenRecorderExtension` target

---

## 4. End-to-end data flow

### Session start
```
SessionSetupView (parent)
  └── RPSystemBroadcastPickerView tap
        └── ReplayKit presents system picker
              └── User confirms
                    └── SampleHandler.broadcastStarted()
                          ├── AVAssetWriter created (temp dir)
                          ├── Darwin observer registered (listens for stopBroadcast)
                          ├── broadcastActive = true (App Group)
                          └── LatestRecordingPath set (App Group)

UIScreen.capturedDidChange → handleCaptureChange()
  └── KidSessionViewModel.startSession()
```

### Session end (parent taps "End")
```
KidSessionViewModel.endSessionEarly()
  ├── postStopBroadcast() → Darwin notification
  │     └── SampleHandler.triggerStop()
  │           └── finishBroadcastWithError()
  │                 └── ReplayKit calls broadcastFinished()
  │                       ├── finishWriting (semaphore blocks)
  │                       ├── moveRecordingToAppGroup()
  │                       │     └── posts recordingReady (Darwin)
  │                       └── broadcastActive = false
  │
  └── finishAndPersistSession()
        └── runSessionAnalysis()
              ├── waitForBroadcastEnded() — polls isCaptured
              ├── waitForRecordingReady() — waits for Darwin recordingReady
              └── executePipeline(recordingURL)
```

### ML pipeline (executePipeline)
```
ScreenRecordingFrameExtractor  →  extracts frames at 3s intervals
  └── for each frame:
        PipelineOrchestrator
          ├── CLIPClassifier.classify()        — screen category (social media, gaming, etc.)
          ├── VisionAnalyzer.analyze()         — OCR, scene hints
          ├── CreatorHandleExtractor.extract() — @handles (pipeline still runs; UI hidden)
          └── AudioProcessor (Whisper)         — transcript, tone
        └── LLMSummaryGenerator               — prose summary, offline activity suggestion
```

---

## 5. App Group layout

```
group.<prefix>.don-ten-team.shared/
  ├── screen_recording_<timestamp>.mp4   ← final recording (written by extension)
  ├── extension_debug.log                ← timestamped extension log
  └── UserDefaults (suite name = group ID)
        ├── LatestRecordingPath          → "/path/to/screen_recording_*.mp4"
        ├── TargetSessionDurationMinutes → Int (0 = no timer)
        └── broadcastActive              → Bool
```

---

## 6. Detecting that a broadcast is active (main app)

`KidSessionActiveView` is presented from `SessionSetupView` when screen recording is enabled and capture begins. That used to depend only on `UIScreen.main.isCaptured`, which often stays **false** when a USB-C / HDMI external display is connected — ReplayKit may attach capture to the external `UIScreen` instead.

**`BroadcastCaptureStatus`** (`team-10-c3/Shared/BroadcastCaptureStatus.swift`):

| API | Use |
|-----|-----|
| API | Use |
|-----|-----|
| `isBroadcastConfirmedForSessionStart` | Main-screen `isCaptured` **or** `broadcastActive` — required to **start** session (after Start tap) |
| `isExternalScreenCaptured` | Often true when a monitor is plugged in — **ignored** for session start (false positive) |
| `isExtensionBroadcastActive` | App Group flag from extension |
| `isCaptureInProgress` | Any screen captured **or** extension flag — used when **waiting for stop** / ending analysis |

**Session setup flow (recording on):**

1. Toggle “Record your screen” — preference only; does **not** navigate or start a session (even with a monitor connected).
2. Tap **Start Session** — system broadcast picker.
3. Confirm broadcast → `broadcastStartArmed` + `isBroadcastConfirmedForSessionStart` → timer screen (`KidSessionActiveView`).

Polling (500 ms) only runs while recording is enabled but returns immediately until step 2 arms the flow.

**Why the toggle used to jump to the active screen on a monitor:** Lightning/HDMI mirroring sets `isCaptured` on the **external** `UIScreen` even when ReplayKit is off. Older code treated that like a confirmed broadcast and auto-armed the session.

`broadcastActive` is cleared only in `KidSessionViewModel.resetAfterEndScreen()`.

---

## 7. Darwin notification names

Both names are derived from the App Group identifier at runtime, making them unique
per-developer even when multiple developers share the same device:

```
<group_id>.recordingReady   — extension → app (recording file is ready)
<group_id>.stopBroadcast    — app → extension (please stop recording)
```

All Darwin notification constants live in `BroadcastNotifications.swift`
(BroadcastShared, compiled into both targets).

---

## 8. Design decisions and gotchas

### Why semaphore in `broadcastFinished` is safe
`broadcastFinished` is iOS's signal that the extension process will terminate soon.
We **must** block until writing is done. `writer.finishWriting` dispatches its
completion on AVFoundation's internal queue (different from the ReplayKit session
queue), so `semaphore.wait` on the ReplayKit thread does not deadlock.
Timeout is 15 s (generous; normal finish takes < 2 s).

### Why Darwin callbacks call `finishBroadcastWithError`, not `finalizeAndSave`
Calling `finalizeAndSave` from Darwin + `broadcastFinished` created a double-finalize
race. The new design routes all stop requests through `finishBroadcastWithError` →
`broadcastFinished` → single finalize path. `stopRequested` flag prevents multiple
`finishBroadcastWithError` calls from Darwin + timer racing each other.

### Why `CIContext` for scaling (not `VTPixelTransferSession`)
`VTPixelTransferSession` requires `VideoToolbox.framework` to be explicitly linked.
`CIContext` is available via CoreImage which ships with ReplayKit extensions without
additional framework linking. Quality is equivalent at 1 fps.

### Why frames are scaled to ≤720 px (not original resolution)
1 fps at full iPhone resolution (≥1170×2532) produces unnecessarily large files for the
ML pipeline, which only needs enough detail for CLIP classification and OCR.
720 px on the long edge matches what `ScreenRecordingFrameExtractor.downscale` uses
for in-memory analysis frames.

### Why the extension writes to temp dir first
On some devices, `mediaserverd` (which `AVAssetWriter` uses under the hood) cannot
write directly into App Group containers due to sandbox restrictions. The extension
writes to `FileManager.temporaryDirectory` (its own sandbox) then moves the file on
`broadcastFinished`. The `LatestRecordingPath` is set to the final App Group path
during `broadcastStarted` (before the file exists) and updated again after the move.

### Creator handles: pipeline vs UI
`CreatorHandleExtractor` still runs during analysis. `PipelineResult.creators` is still
populated. The UI display (`SessionResultView`, `SessionScreenDetailView`,
`TimelineRowView`, `RecordingTestView`, `MainViewTest`) has been removed per product
request. Re-enabling it requires adding back the `if !result.creators.isEmpty` blocks.

---

## 9. Reading the extension debug log

The extension logs every significant event with an emoji prefix:

| Prefix | Meaning |
|--------|---------|
| 🚀 | `broadcastStarted` fired |
| ✅ | Success (writer ready, file moved, etc.) |
| ❌ | Error (App Group inaccessible, writer failed, etc.) |
| ⏱ | Timer / Darwin stop signal |
| 📏 | First-frame locked encode size |
| 📐 | Display topology change detected mid-session |
| ⚡️ | `startWriting` result |
| 📲 | Darwin stop notification received |
| 🛑 | `triggerStop` called |
| 🏁 | `broadcastFinished` entered |
| ⚠️ | Writer not in expected state (non-fatal) |

**Fetch the log from the app:**
```swift
let log = BroadcastExtensionLog.read() ?? "(empty)"
print(log)
```

**Fetch from Xcode:**
Xcode → Window → Devices & Simulators → select device → select app →
"Download Container…" → AppData/Shared/extension_debug.log

A healthy end-of-log looks like:
```
[...] 🛑 triggerStop: Session timer completed
[...] 🏁 broadcastFinished
[...] ✅ Recording moved to App Group: screen_recording_1234567890.mp4
[...] ✅ broadcastFinished complete
```

---

## 10. Manual test matrix

### Baseline (must pass before any other test)

1. Open the app → start a session with screen recording enabled.
2. Let the session run ~30 s.
3. Tap "End Session".
4. Verify:
   - Status bar broadcast indicator clears within ~15 s.
   - `extension_debug.log` ends with `✅ broadcastFinished complete`.
   - `LatestRecordingPath` in App Group defaults points to a valid MP4 > 50 KB.
   - Analysis starts automatically and produces a result.

### Wired display — active session screen

1. Enable “Record your screen” on the Session tab.
2. Connect USB-C / HDMI external display (before or after).
3. Start the broadcast from the picker.
4. Verify **Kid Session Active** (timer + “End Session Early”) appears within ~1 s even if the phone’s status bar does not show the recording indicator on the built-in display.

### Wired display — recording survives

1. Start a session with screen recording.
2. Connect a USB-C or HDMI external monitor mid-session.
3. Use the device for ~2 min with the external display active.
4. End the session.
5. Verify:
   - Log contains `📐 Display size changed` lines but NO `Writer not in writing state` errors.
   - A valid MP4 is produced and analysis completes.

### Stop reliability

1. Start a session, immediately tap "End Session" (< 5 s recording).
2. Verify broadcast indicator clears and analysis runs.
3. Repeat 3×; confirm no hang and no stuck status bar.

### Auto-stop timer

1. Set `RecordingManager.shared.setSessionDuration(minutes: 1)` in a debug context.
2. Start session with recording.
3. Wait for auto-stop; verify `⏱ GCD auto-stop timer fired` in log and recording saved.

### Failure recovery

1. Force-quit the app while a broadcast is in progress.
2. Relaunch; verify the extension stops (status bar clears within ~15 s via Darwin timer).

---

## 11. Out of scope

- In-app ReplayKit stop UI — all stop is via Darwin notify from `RecordingManager`.
- Screen flow changes (`SessionSetupView`, `KidSessionActiveView`, navigation).
