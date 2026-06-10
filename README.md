# Kiddly

Kiddly is a native iOS SwiftUI app that helps parents manage child screen time — starting sessions, monitoring usage, setting rules, and getting parenting guidance. The codebase follows MVVM with dependency injection via `AppContainer`, on-device persistence via SwiftData, and a typed local feature flag system for toggling work-in-progress features.

**Requirements:** Xcode 26.5+, iOS 26+ simulator or device.

- [Screen Time data & limitations](docs/SCREEN_TIME.md) — embedded `DeviceActivityReport` extension, session timer, and Apple API limits.
- [Child data storage](docs/CHILD_DATA_STORAGE.md) — SwiftData schema, child profiles, session markers, and what is persisted vs in-memory.

## Building with your own Apple account

Each teammate can build with their **own** signing identity. Shared defaults live in `Config/Signing.xcconfig`; personal overrides go in a gitignored local file.

### First-time setup

1. Clone the repo and open `team-10-c3.xcodeproj`
2. Copy the signing template:
   ```bash
   cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
   ```
3. Edit `Config/Signing.local.xcconfig`:
   ```xcconfig
   APP_BUNDLE_ID_PREFIX = yourname
   DEVELOPMENT_TEAM = XXXXXXXXXX
   ```
   Find your **Team ID** in Xcode → Settings → Accounts → your team → Team ID.
4. Register an **App Group** at [developer.apple.com](https://developer.apple.com) → Identifiers → App Groups:
   - Identifier: `group.yourname.don-ten-team.shared` (derived from your prefix)
5. In Xcode, for all targets (`team-10-c3`, `ScreenRecorderExtension`, `DeviceActivityMonitorExtension`, `DeviceActivityReportExtension`):
   - **Signing & Capabilities** → enable **Automatically manage signing**
   - Confirm **Team** matches your local config
   - Add the App Group capability if Xcode prompts you
6. Select scheme **`team-10-c3`** and an **iPhone 17** simulator → **⌘B**

### Family Controls (optional)

The main app includes a Family Controls entitlement. If Apple has **not** approved it for your team, add this to `Config/Signing.local.xcconfig`:

```xcconfig
MAIN_APP_ENTITLEMENTS = team-10-c3/team-10-c3.dev.entitlements
```

Screen recording and most UI work still run without Family Controls.

### What gets customized per person

| Setting | Example (Abui) | Example (teammate) |
|---|---|---|
| Team ID | `35SGY39Y8Z` | their Team ID |
| Main bundle ID | `abui.don-ten-team` | `daffa.don-ten-team` |
| App Group | `group.abui.don-ten-team.shared` | `group.daffa.don-ten-team.shared` |

Do **not** commit `Config/Signing.local.xcconfig`.

## Contents

- [Project Structure](#project-structure)
- [Feature Flags](#feature-flags)
  - [Overview](#overview)
  - [Architecture](#architecture)
  - [Quick Start](#quick-start)
  - [Adding a New Flag](#adding-a-new-flag)
  - [Flag Registry](#flag-registry)
  - [API Reference](#api-reference)
  - [Usage Examples](#usage-examples)
  - [Conventions](#conventions)
  - [Persistence](#persistence)
  - [Previews and Testing](#previews-and-testing)
  - [Troubleshooting](#troubleshooting)
  - [FAQ](#faq)

## Project Structure

```text
Kiddly/
│
├── App/                    Entry point, routing, and dependency setup
│
├── DesignSystem/           Shared UI components and visual tokens
│                           (colors, typography, reusable views like timer ring, alarm overlay)
│
├── Features/               One folder per screen group
│   ├── Onboarding/         First-time parent setup
│   ├── Dashboard/          Home screen — shows all children at a glance
│   ├── KidSession/         The core handoff flow — setup, countdown, alarm
│   ├── Profiles/           Manage children + browse their session history
│   ├── Rules/              Set screen time schedules and category limits       [P2]
│   ├── WeeklySummary/      Weekly digest of what the child watched/played      [P2]
│   ├── Guidance/           Parenting advice, response scripts, offline ideas   [P2]
│   ├── Privacy/            What's collected, audit log, transparency           [P3]
│   └── Negotiation/        Child requests extra time, parent approves/declines [P4]
│
├── Models/                 All data models stored on device (SwiftData)
│                           (child profiles, sessions, rules, summaries, guidance)
│
├── Services/               All business logic
│   ├── FeatureFlags/       Local on/off feature flag system
│   └── ...                 (session timer, Face ID, notifications, ML pipeline, rules engine)
│
├── Repositories/           Read/write data to and from SwiftData
│
├── MLEngine/               The AI content analysis engine
│                           (copied from existing project — MobileCLIP, Whisper, Vision, etc.)
│
└── Shared/                 Files shared between the main app and the broadcast extension
                            (recording constants, handoff, video writer)


Extensions/
├── BroadcastUpload/        Captures the screen while the child uses the device  [P1]
├── DeviceActivityMonitor/  Fires when a screen time limit is reached             [P2]
├── DeviceActivityReportExtension/  Embedded Screen Time usage reports (sandboxed)   [done]
└── ShieldConfiguration/    Custom "time's up" screen shown to the child          [P2]
```

---

## Feature Flags

### Overview

Feature flags let you turn app features on or off without removing code. Use them to:

- Hide incomplete features from users while development continues
- Enable features locally during development
- Ship a single binary with features toggled off until ready

This is a **local-only** system: simple on/off booleans stored on device. There is no remote config, no rollout percentages, and no debug settings UI.

### Architecture

```text
FeatureFlag enum (registry + metadata)
        │
        ▼
FeatureFlagService (in-memory cache + @Observable)
        │
        ├── FeatureFlagStorage protocol
        │       ├── UserDefaultsFeatureFlagStorage  (production)
        │       └── InMemoryFeatureFlagStorage      (previews / tests)
        │
        └── SwiftUI
                ├── EnvironmentValues.featureFlags
                └── View.featureGated(_:)
```

**Resolution order** when reading a flag:

1. In-memory cache (fast path)
2. UserDefaults stored value (if set)
3. Compile-time `defaultValue` from flag metadata

**File layout:**

```text
team-10-c3/Services/FeatureFlags/
├── FeatureFlag.swift              # enum registry + per-flag metadata
├── FeatureFlagProviding.swift     # protocol consumed by views / view models
├── FeatureFlagStorage.swift       # storage protocol + UserDefaults + InMemory
├── FeatureFlagService.swift       # @Observable service with cache
├── FeatureFlagEnvironment.swift   # SwiftUI environment key
└── FeatureFlag+View.swift         # .featureGated view modifier
```

When the flag registry grows past ~15 cases, split metadata into extension files (e.g. `FeatureFlag+Dashboard.swift`) without changing the public API.

### Quick Start

1. Add a case to `FeatureFlag` in `FeatureFlag.swift`
2. Set `defaultValue` and `description` in the `metadata` switch
3. Gate your view with `.featureGated(.yourFlag)` or `featureFlags.isEnabled(.yourFlag)`

### Adding a New Flag

**Step 1 — Register the flag**

```swift
enum FeatureFlag: String, CaseIterable, Sendable, Hashable {
    case weeklySummary
    case negotiation

    var metadata: FeatureFlagMetadata {
        switch self {
        case .weeklySummary:
            FeatureFlagMetadata(
                key: rawValue,
                defaultValue: false,
                description: "Weekly digest screen"
            )
        case .negotiation:
            FeatureFlagMetadata(
                key: rawValue,
                defaultValue: false,
                description: "Child time-extension negotiation flow"
            )
        }
    }
}
```

**Step 2 — Gate the feature**

```swift
WeeklySummaryView()
    .featureGated(.weeklySummary)
```

**Step 3 — Document the flag** in the [Flag Registry](#flag-registry) table below.

**Checklist**

- [ ] Case added to `FeatureFlag` enum
- [ ] `metadata` entry with `defaultValue` and `description`
- [ ] View, route, or ViewModel gated
- [ ] Flag documented in README registry table

### Flag Registry

| Flag | Default | Description |
|------|---------|-------------|
| `weeklySummary` | `false` | Weekly digest screen (example flag) |

Add rows here when new flags are registered.

### API Reference

| API | Type | Purpose |
|-----|------|---------|
| `FeatureFlag` | enum | Typed flag registry — always use cases, never raw strings |
| `FeatureFlagMetadata` | struct | `key`, `defaultValue`, `description` for a flag |
| `FeatureFlagProviding` | protocol | Abstraction for views and view models |
| `FeatureFlagService` | class | Production `@Observable` service with in-memory cache |
| `FeatureFlagStorage` | protocol | Persistence abstraction |
| `UserDefaultsFeatureFlagStorage` | struct | Production storage backed by `UserDefaults` |
| `InMemoryFeatureFlagStorage` | class | Non-persistent storage for previews and tests |
| `isEnabled(_:)` | method | Returns whether a flag is on |
| `set(_:enabled:)` | method | Turn a flag on or off and persist |
| `reset(_:)` | method | Remove stored value; revert to `defaultValue` |
| `setFlags(_:)` | method | Bulk update multiple flags |
| `resetAll()` | method | Reset every registered flag to its default |
| `snapshot()` | method | Current resolved state of all flags |
| `.featureGated(_:)` | View modifier | Hide a view when its flag is off |
| `.featureGated(_:else:)` | View modifier | Show fallback content when flag is off |
| `.environment(\.featureFlags)` | SwiftUI | Inject the flag service into the view tree |

### Usage Examples

**Gate a view (simplest)**

```swift
WeeklySummaryView()
    .featureGated(.weeklySummary)
```

**Gate with fallback**

```swift
WeeklySummaryView()
    .featureGated(.weeklySummary, else: {
        Text("Coming soon")
    })
```

**Gate inline**

```swift
@Environment(\.featureFlags) private var featureFlags

var body: some View {
    if featureFlags.isEnabled(.weeklySummary) {
        WeeklySummaryView()
    }
}
```

**Inject into a ViewModel**

```swift
@MainActor
final class DashboardViewModel {
    private let featureFlags: any FeatureFlagProviding

    init(featureFlags: any FeatureFlagProviding) {
        self.featureFlags = featureFlags
    }

    var showWeeklySummary: Bool {
        featureFlags.isEnabled(.weeklySummary)
    }
}
```

**Seed flags at launch (local dev)**

In [`AppContainer.swift`](team-10-c3/App/AppContainer.swift), customize the convenience initializer:

```swift
convenience init() {
    let featureFlags = FeatureFlagService()
    featureFlags.set(.weeklySummary, enabled: true)
    self.init(featureFlags: featureFlags)
}
```

The app injects this service from [`ParentGuideApp.swift`](team-10-c3/App/ParentGuideApp.swift):

```swift
RootView()
    .environment(\.featureFlags, container.featureFlags)
```

**Preview with flags on**

```swift
#Preview {
    DashboardView()
        .environment(\.featureFlags, FeatureFlagService(
            storage: InMemoryFeatureFlagStorage(initial: [.weeklySummary: true])
        ))
}
```

**Bulk setup**

```swift
featureFlags.setFlags([
    .weeklySummary: true,
    .negotiation: false,
])
featureFlags.resetAll()
```

**Inspect current state**

```swift
let state = featureFlags.snapshot()
// [.weeklySummary: false, .negotiation: false]
```

### Conventions

- Always use `FeatureFlag` enum cases — never hardcode raw strings in views or view models
- Set `defaultValue: false` unless the feature should ship enabled
- Never rename a case's `rawValue` after release — it is the UserDefaults key and breaking changes persist on user devices
- View models depend on `FeatureFlagProviding`, not `FeatureFlagService` directly
- Split the enum into `FeatureFlag+<Domain>.swift` extension files when the registry file exceeds ~80 lines
- Gate navigation routes in `AppRoute` — omit routes for disabled features rather than navigating to empty stubs

### Persistence

Stored values use UserDefaults with this key format:

```text
featureFlag.<rawValue>
```

Example: `featureFlag.weeklySummary`

- **Production** uses `UserDefaultsFeatureFlagStorage` (via `UserDefaults.standard`)
- **Previews and tests** should use `InMemoryFeatureFlagStorage` to avoid polluting real UserDefaults
- **Clear all overrides**: call `resetAll()`, or delete and reinstall the app in Simulator
- **InMemory storage** does not persist — values are lost when the service is deallocated

### Previews and Testing

Use in-memory storage to control flag state without side effects:

```swift
let service = FeatureFlagService(
    storage: InMemoryFeatureFlagStorage(initial: [.weeklySummary: true])
)
```

Inject via environment for SwiftUI previews, or pass to `AppContainer(featureFlags:)` for integration testing when a test target is added.

`FeatureFlagProviding` is a protocol — create a test double that returns fixed values for unit tests on view models.

### Troubleshooting

| Problem | Likely cause | Fix |
|---------|--------------|-----|
| UI not updating after `set` | Service not in SwiftUI environment | Ensure `.environment(\.featureFlags, container.featureFlags)` is set on the root view |
| Flag stuck on | UserDefaults override from a previous session | Call `reset(_:)` or `resetAll()` |
| Preview shows wrong state | Using UserDefaults-backed service in preview | Use `InMemoryFeatureFlagStorage` in `#Preview` |
| Flag always returns default | Case not in enum or wrong case name | Verify the `FeatureFlag` case exists and matches usage |
| Build error after adding flag | Missing `metadata` switch case | Add a `metadata` entry for every enum case |

### FAQ

**Can I add remote config later?**

Yes. Implement `FeatureFlagStorage` with a remote backend that fetches values and caches them locally. The rest of the system stays unchanged.

**Should I gate navigation routes?**

Yes. Check `isEnabled(_:)` before pushing a route, or omit disabled routes from your route enum handling entirely.

**Where do I turn flags on for local development?**

In `AppContainer`'s initializer — call `featureFlags.set(_:enabled: true)` for the flags you need.

**Why is there an example `weeklySummary` flag?**

Swift requires at least one enum case for `String`-backed enums. Replace or remove it when you add real flags.

**Does changing a flag re-render SwiftUI views?**

Yes. `FeatureFlagService` is `@Observable`; views that read `isEnabled(_:)` through the environment update automatically when flags change.
