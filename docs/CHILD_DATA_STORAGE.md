# Child data storage in ParentGuide

This document explains how child profiles and child-linked session data are stored on device, how reads and writes flow through the app, and what is **not** persisted.

## Overview

| Property | Value |
|----------|-------|
| **Storage engine** | [SwiftData](https://developer.apple.com/documentation/swiftdata) (`ModelContainer`) |
| **Location** | Default on-device SQLite store (app sandbox) |
| **Sync** | None — all child data is local-only |
| **Child ↔ session link** | `UUID` foreign keys (`childId`), not SwiftData relationships |

Child profiles are the anchor identity for sessions, usage snapshots, and ML analysis. Everything else that references a child stores `childId: UUID` and queries by that id.

## SwiftData schema

`AppContainer.makeModelContainer()` registers four `@Model` types in one schema:

```swift
Schema([
    Child.self,
    SessionMarker.self,
    SessionUsageSnapshot.self,
    SessionAnalysisRecord.self,
])
```

| Model | Purpose | Key fields |
|-------|---------|------------|
| `Child` | Profile shown in the dashboard and kid-session flow | `id`, `name`, `dateOfBirth`, `genderRawValue`, `avatarAssetName` |
| `SessionMarker` | Start/stop events for a parent session | `childId`, `timestamp`, `typeRaw` (`.start` / `.stop`) |
| `SessionUsageSnapshot` | Timer snapshot when a session ends | `childId`, `startAt`, `stopAt`, `totalSeconds`, `plannedDurationSeconds` |
| `SessionAnalysisRecord` | Cached ML pipeline output for one session | `sessionId` (start-marker id), `childId`, `payloadJSON`, `statusRaw` |

Source files:

- [`team-10-c3/Models/Child.swift`](../team-10-c3/Models/Child.swift)
- [`team-10-c3/Models/SessionMarker.swift`](../team-10-c3/Models/SessionMarker.swift)
- [`team-10-c3/Models/SessionUsageSnapshot.swift`](../team-10-c3/Models/SessionUsageSnapshot.swift)
- [`team-10-c3/Models/SessionAnalysisRecord.swift`](../team-10-c3/Models/SessionAnalysisRecord.swift)

### Child profile fields

```text
Child
├── id: UUID              (stable key for all child-linked records)
├── name: String
├── dateOfBirth: Date     (age derived at read time via currentAge)
├── genderRawValue: String (Gender enum: boy / girl / preferNotToSay)
└── avatarAssetName: String (ImageAsset name, default childAvatar1)
```

Gender is stored as a raw string because SwiftData persists simple types; `gender` is a computed property over `genderRawValue`.

## Architecture

```text
ParentGuideApp
    └── AppContainer (launch)
            ├── ModelContainer (SwiftData)
            │       └── mainContext
            ├── SwiftDataChildRepository
            ├── SwiftDataSessionRepository
            ├── SessionAnalysisStore
            └── ProfileViewModel.loadChildren()

SwiftUI views
    └── @Environment(\.childRepository)
    └── @Environment(\.profileViewModel)
```

Wiring happens in [`team-10-c3/App/AppContainer.swift`](../team-10-c3/App/AppContainer.swift) and [`team-10-c3/App/ParentGuideApp.swift`](../team-10-c3/App/ParentGuideApp.swift). The same `ModelContainer` is injected into the SwiftUI scene via `.modelContainer(container.modelContainer)`.

## Child repository

[`ChildRepository`](../team-10-c3/Repositories/ChildRepository.swift) is the only write path for child profiles.

| Method | Behavior |
|--------|----------|
| `save(_ child: Child)` | `modelContext.insert(child)` then `save()` |
| `fetchAll()` | All children sorted by `name` ascending |

### Implementations

| Class | Used when |
|-------|-----------|
| `SwiftDataChildRepository` | Production — backed by `ModelContainer.mainContext` |
| `InMemoryChildRepository` | SwiftUI previews and tests |

The environment default is in-memory ([`ChildRepositoryEnvironment.swift`](../team-10-c3/Repositories/ChildRepositoryEnvironment.swift)); the real app overrides it at launch.

### Create flow

```text
ProfileFormView
    → ProfileFormViewModel.confirmSave()
        → Child(...) built from form fields
        → childRepository.save(child)
    → ProfileViewModel.handleChildSaved(child)
        → loadChildren()
        → selectedChild = child
```

[`ProfileFormViewModel`](../team-10-c3/Features/Profiles/ProfileFormViewModel.swift) only supports **create**. There is no update or delete API on `ChildRepository` today, despite the form header comment mentioning edit.

## Child-linked session data

Sessions are scoped per child via `childId`. [`SessionRepository`](../team-10-c3/Repositories/SessionRepository.swift) owns markers and usage snapshots.

### Session markers

On session start/stop, the app inserts a `SessionMarker`:

```text
recordMarker(childId, type: .start | .stop, timestamp)
```

Active sessions are derived by pairing markers — the latest unpaired `.start` per child with no later `.stop`. See `SessionMarkerPairing.unpairedActiveSessions`.

At most **one global active session** is allowed. `resolveGlobalActiveSession()` auto-inserts `.stop` markers for orphaned actives on other children.

### Usage snapshots

On session stop, `saveUsageSnapshot` persists wall-clock timer data:

| Field | Meaning |
|-------|---------|
| `totalSeconds` | Parent session timer (pause-aware) |
| `plannedDurationSeconds` | Limit chosen at start (e.g. 30 min) |
| `appUsageJSON` | Legacy; new saves use `"[]"` — per-app usage is fetched live for charts |

Deduplication: if a snapshot already exists for the same `(childId, startAt, stopAt)` window, the richer row is kept and duplicates are deleted.

For chart behavior and what is *not* stored in snapshots, see [SCREEN_TIME.md](./SCREEN_TIME.md).

### ML analysis cache

[`SessionAnalysisStore`](../team-10-c3/Repositories/SessionAnalysisStore.swift) persists pipeline results keyed by **start-marker** `sessionId`:

```text
save(sessionId, childId, result, errorMessage)
    → upsert SessionAnalysisRecord (delete existing, insert new)
    → payloadJSON = encoded StoredPipelineResult
```

`childId` is stored on the record for filtering but the primary lookup key is `sessionId`.

## In-memory state (not persisted)

These values live only for the current app session:

| State | Owner | Notes |
|-------|-------|-------|
| `selectedChild` | `ProfileViewModel` | Defaults to first child after `loadChildren()`; reconciled if stale |
| `selectedChild` (session flow) | `KidSessionViewModel` | Synced from `ProfileViewModel`; locked while a session is active |
| Dashboard display cache | `SessionCoordinator.displayStateByChild` | Per-child chart/banner state in memory |

On cold launch, `AppContainer` calls:

1. `profileViewModel.loadChildren()` — restores child list from SwiftData
2. `kidSessionViewModel.reconcilePersistedSession(...)` — resumes an active session if markers say one is open

There is no `UserDefaults` key for “last selected child.”

## App Group storage (not child-specific)

Some Screen Time and broadcast state uses the shared App Group (`UserDefaults`), but it is **device/session scoped**, not per child:

| Store | Key idea |
|-------|----------|
| `FamilyActivitySelectionStore` | Encoded TikTok/YouTube token selection |
| `RecordingManager` / `BroadcastCaptureStatus` | Recording handoff between app and extension |
| `SessionShieldStore` | Active shield state during a session |

These do not store child profile fields or `childId`.

## Store migration and reset

If `ModelContainer` creation fails (e.g. schema mismatch after adding `screenTimeAppTotalSeconds`), `AppContainer` deletes the SQLite store and WAL/SHM sidecars once, then recreates the container. **All local data is wiped** in that recovery path.

## Query patterns by feature

| Feature | How it finds child data |
|---------|-------------------------|
| Dashboard | `profileViewModel.selectedChild` → `SessionCoordinator.refresh(for:)` → queries by `child.id` |
| Kid session | `selectedChild.id` → `recordMarker` / `saveUsageSnapshot` |
| Weekly summary | `profileViewModel.selectedChild?.id` → `fetchSnapshots(for:month:)` + `SessionAnalysisStore` |
| Session history (planned) | `ProfileDetailView` shows profile only; history UI not wired yet |

## Current limitations

- **No edit/delete** for child profiles through `ChildRepository`
- **No cloud backup** or multi-device sync
- **No referential integrity** — deleting a `Child` row (if done manually) would leave orphan markers/snapshots/analysis rows with stale `childId`s
- **Agreement copy** mentions deleting data from Settings, but a full data-delete settings action is not implemented in code yet

## Adding a new child-linked model

1. Add `@Model` type under `team-10-c3/Models/`
2. Include it in `AppContainer.makeModelContainer()` schema array
3. Store `childId: UUID` (or `sessionId` + `childId` for session-scoped data)
4. Add repository or store methods that filter by `childId`
5. Plan a schema migration or accept one-time store reset for existing installs

## Related docs

- [SCREEN_TIME.md](./SCREEN_TIME.md) — how usage charts relate to persisted snapshots
- [BROADCAST.md](./BROADCAST.md) — screen recording during a child session
