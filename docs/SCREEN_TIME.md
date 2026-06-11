# Screen Time data in Kiddly

This document explains how Kiddly uses Apple's Screen Time APIs, what parents should expect on the dashboard, and what the platform allows.

## What parents see

| Metric | Source | Accuracy |
|--------|--------|----------|
| **Session time (today)** | Kiddly session timer (start/stop, pause-aware) | Exact for time the session was active |
| **Last Screen Time (banner)** | Parent session timer for the most recent session | Exact session length |
| **Usage report + app list** | Embedded `DeviceActivityReport` (report extension sandbox) | Approximate Apple estimates |
| **Weekly usage report** | Same embedded report on Usage Insight | Visual only in extension |
| **Settings → Screen Time** | Apple's full-day view | Optional ground truth for the whole device |

Session time and per-app usage answer different questions. They will not always add up.

## Shared parent phone (default model)

Kiddly runs on the parent's iPhone while the child uses it during sessions. Apple does **not** expose a per-Kiddly-child Screen Time identity on one device (`users: .children` requires the child's own device in Family Sharing).

Instead, the main app scopes each report to:

1. **Session windows** for the selected `childId` (start/stop markers in SwiftData)
2. **Allowed-app tokens** from the parent's Allowed Apps selection
3. **`users: .all`** on this device

Each child profile gets its own `DeviceActivityFilter` with a different `DateInterval`. Switching children switches the filter; data does not mix between profiles in the UI.

**Chart granularity**: the report extension aggregates Apple's segments into **hourly** bars (0–23) and **total seconds per app** within the session window.

**Limitation**: Apple cannot distinguish parent vs child on the same phone. Usage during a child's session window is attributed to that child's report. Gaps between two sessions on the same day are included in the union bounding box (parent allowed-app usage in the gap may appear).

## Architecture (no main-app `activityData`)

Kiddly no longer calls `DeviceActivityData.activityData` from the main app (which required `approvedWithDataAccess` on iOS 26.4+ in many regions).

Instead:

1. **Main app** builds a per-child `DeviceActivityFilter` and embeds `DeviceActivityReport(context, filter:)` in the dashboard and weekly summary.
2. **DeviceActivityReportExtension** (ExtensionKit, `com.apple.deviceactivityui.report-extension`) receives usage in `makeConfiguration(representing:)` and renders SwiftUI charts inside the sandbox.
3. **DeviceActivityMonitorExtension** continues to re-apply app shields on `intervalDidStart` / clear on `intervalDidEnd`.

```text
Dashboard / Weekly Summary
  → SessionRepository.completedSessionWindows(childId, day)
  → union DateInterval + allowed apps
  → DeviceActivityReport(.sessionToday | .sessionWeek, filter)
  → Report extension renders usage (no data exported to main app)

Session start/stop
  → DeviceActivityCenter monitoring + ManagedSettings shields
  → Timer snapshot saved (totalSeconds only)
```

## Sandbox constraint

Apple sandboxes the report extension: it can read usage and render UI, but cannot write to App Group, SwiftData, or pass structured usage back to the main app. AI summaries use session timer + recording transcripts only—not programmatic top-app strings.

## App blocking during sessions

When a parent session **starts**, Kiddly applies a **ManagedSettings** shield (`SessionAppShield` + `SessionShieldStore`):

- **Category policy**: shield all app categories except allowed-app tokens (`.all(except:)`).
- **Per-app blocklist**: shield every other installed app token from parent **Allowed Apps** selection.
- **Web**: shield web domain categories.
- **Device Activity Monitor extension** re-applies shields when monitoring starts.

Shields clear on session stop and on app launch if no session is active.

- Requires **Screen Time / Family Controls** authorization (`.approved` is enough for blocking and embedded reports).
- Parent must select allowed apps once in **Parent's Access → Allowed Apps** before the first session.
- Test on a **physical device**; the simulator does not enforce shields reliably.
- In **Screen Time debug**, check App Group key `deviceActivityExtensionHeartbeat` after starting a session.

## Filters

- **Today (dashboard / daily insight)**: `SessionReportFilterBuilder.todaySessionsFilter` — `.hourly(during: unionOfChildSessionWindows)`, scoped to allowed-app tokens. Active session extends the window to `now`.
- **Week (usage insight)**: `SessionReportFilterBuilder.weekSessionsFilter` — `.weekly(during: unionOfAllSessionWindowsThatWeek)` for the selected child.
- **No sessions**: filter is `nil`; UI shows empty state.

## Save vs display

**On session stop** we only persist:

- Start/stop **markers**
- **Timer snapshot** (`totalSeconds`, `plannedDurationSeconds`)

**For Latest Summary** the main app builds the report filter from the selected child's session windows and embeds the report. No per-app JSON is fetched or stored in the main app.

## What we cannot promise

- Per-app minutes that exactly match session time when multiple apps were used.
- Separating parent vs child usage on the same device during a session window.
- Programmatic usage totals in the main app or AI copy.
- Export or charts that match Settings → Screen Time for the full day.
- Report extension reliability (known Apple bugs)—pull to refresh bumps the report via `reportRefreshToken`.

## Parent-facing copy guide

| Moment | Example copy |
|--------|--------------|
| Hero | **Session time (today): X** — "Measured while sessions were active." |
| Per-app section | **App usage (estimate)** — "Estimated allowed-app usage on this device during [child]'s sessions." |
| Empty report | "No app usage for this period yet. End a session or pull to refresh." |

## Debugging

Use **Settings → Screen Time debug** to inspect authorization, monitor extension heartbeat, and session timer logs. Usage UI itself only renders inside the report extension.
