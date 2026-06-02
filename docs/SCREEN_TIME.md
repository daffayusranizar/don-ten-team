# Screen Time data in ParentGuide

This document explains how ParentGuide uses Apple's Screen Time APIs, how we aggregate usage for parent sessions, and what parents should expect on the dashboard.

## What parents see

| Metric | Source | Accuracy |
|--------|--------|----------|
| **Session time (today)** | ParentGuide session timer (start/stop, pause-aware) | Exact for time the session was active |
| **Last Screen Time (banner)** | Parent session timer for the most recent session | Exact session length |
| **24h stacked chart + app list** | Live `activityData` per calendar hour for today's sessions | Approximate Apple estimates |
| **Settings → Screen Time** | Apple's full-day view | Optional “ground truth” for the whole device |

Session time and per-app bars answer different questions. They will not always add up.

## Apple API limits

- **No per-minute per-app buckets** for arbitrary session windows. `DeviceActivityFilter` supports hourly, daily, and weekly segments only.
- **`totalActivityDuration` per application** is the main per-app signal inside a segment—not foreground-only minute tracking.
- **EU / data access**: On iOS 26.4+, reliable usage requires `AuthorizationCenter` status `approvedWithDataAccess` (not merely `approved`). The app calls `ensureUsageAuthorization()` before chart fetch so Apple’s Screen Time permission sheet is shown when needed.
- **No Settings parity**: We cannot reproduce Settings → Screen Time totals inside a custom session chart.

## What ParentGuide uses

- **`DeviceActivityData.activityData`** only—no `DeviceActivityReport`, no report extension, no App Group export for usage charts.
- **Filter**: One `activityData` query **per calendar hour** touched by any session that day (`SessionActivityFilterBuilder.filterForHour`).
- **Noise**: `SessionUsageNoiseFilter` drops system/background bundles before display.

## Save vs chart (important)

**On session stop** we only persist:

- Start/stop **markers**
- **Timer snapshot** (`totalSeconds`, `plannedDurationSeconds`) — no per-app JSON

**For Latest Summary** (`SessionCoordinator.loadHourlySummaryUsage`):

1. Load all **completed session windows** for the calendar day (markers, with snapshot fallback).
2. **Union** calendar hours touched by any session.
3. For each hour: one `activityData` fetch (live + cached, best payload).
4. Keep segments that overlap **any** session in that hour; **max** per app per hour; **sum** across hours for the app list and stacked chart.

| Case | Behavior |
|------|----------|
| Two sessions same hour | One hourly query; segments count if they overlap either session |
| Same app, duplicate rows in one hour | **max**, not sum |
| Same app across hours | **sum** hour buckets (chart stacks by hour) |
| Session covered only part of an hour | Chart bars for that hour use a **dotted** fill (partial-hour marker) |
| Last Screen Time banner | Always exact session timer, not app sum |

## Per-day Latest Summary (timers)

`DayActivitySummary` (in `SessionRepository`) rolls up timer snapshots for the calendar day:

- **`totalSeconds`** — Sum of each snapshot's session timer.
- **`sessionCount`** — Number of snapshots that day; title e.g. **Today (2 sessions)**.

Per-app chart and list data come from the **live hourly fetch**, not from the database.

## What we cannot promise

- Per-app minutes that exactly match session time when multiple apps were used.
- Foreground-only usage.
- Export or charts that match Settings → Screen Time for the full day.

We do **not** fetch `.daily` whole-day API for the chart.

## Parent-facing copy guide

| Moment | Example copy |
|--------|--------------|
| Hero | **Session time (today): X** — "Measured while sessions were active." |
| Per-app section | **App usage (estimate)** — "From iOS Screen Time for today. Times are approximate." |
| Loading chart | "Loading app usage…" |
| Empty apps | "No app usage for this period yet. End a session or pull to refresh." |
| Multi-session | **Today (2 sessions)** from `DayActivitySummary.periodTitle` |

## Fetch timing

- **Session stop** — Record stop marker, `stopMonitoring()`, save timer snapshot only (fast). Chart loads asynchronously.
- **Dashboard / pull to refresh** — `fetchHourlyUsageForSessions`: single pass, one query per union hour (no 2s/4s/6s retry loop).
- **Debug** — `fetchUsage` (single session) still uses triple-attempt aggregation for diagnostics.

## Debugging

Use **Settings → Screen Time debug** to inspect pipeline logs: `hourly+` filter labels, `agg=max` per hour. Last Screen Time banner uses session timer; Latest Summary chart uses live hourly data across today's sessions.
