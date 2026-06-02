# Screen Time data in ParentGuide

This document explains how ParentGuide uses Apple's Screen Time APIs, how we aggregate usage for parent sessions, and what parents should expect on the dashboard.

## What parents see

| Metric | Source | Accuracy |
|--------|--------|----------|
| **Session time (today)** | ParentGuide session timer (start/stop, pause-aware) | Exact for time the session was active |
| **Last Screen Time (banner)** | Parent session timer for the most recent session | Exact session length |
| **App usage (estimate)** | iOS `activityData` for session windows, merged per day | Approximate; capped per session |
| **Settings → Screen Time** | Apple's full-day view | Optional “ground truth” for the whole device |

Session time and per-app bars answer different questions. They will not always add up.

## Apple API limits

- **No per-minute per-app buckets** for arbitrary session windows. `DeviceActivityFilter` supports hourly, daily, and weekly segments only.
- **`totalActivityDuration` per application** is the main per-app signal inside a segment—not foreground-only minute tracking.
- **EU / data access**: On iOS 26.4+, reliable usage requires `AuthorizationCenter` status `approvedWithDataAccess` (not merely `approved`). The app calls `ensureUsageAuthorization()` before start/stop fetch so Apple’s Screen Time permission sheet is shown when needed.
- **No Settings parity**: We cannot reproduce Settings → Screen Time totals inside a custom session chart.

## What ParentGuide uses

- **`DeviceActivityData.activityData`** only—no `DeviceActivityReport`, no report extension, no App Group export for usage charts.
- **Filter**: `hourly+session` built in `SessionActivityFilterBuilder` (session window clipped to hourly segment interval).
- **Noise**: `SessionUsageNoiseFilter` drops system/background bundles before display and persistence.

## Session window + wall-clock cap (per session)

When a session stops, `DeviceActivityUsageAggregator` processes each activity segment that overlaps `[sessionStart, sessionStop)`:

1. **Session overlap** — Keep rows whose segment interval intersects the session window.
2. **Per app** — **Sum** all raw `totalActivityDuration` values for the same bundle in that session (no hourly dedupe).
3. **Wall-clock cap** — Each app's stored `durationSeconds` is `min(sum, sessionWallClockSeconds)` where wall-clock is `stopAt − startAt`.
4. **Session timer in snapshot** — Wall-clock elapsed at stop (`totalSeconds` on save)—not the sum of apps.

| Case | Behavior |
|------|----------|
| Same app, multiple API rows in one session | **Sum** raw rows, then **cap** at session timer (e.g. 1:14–1:16 TikTok 2m + 1:17–1:19 TikTok 2m → **4m** if session ≥ 4m) |
| Inflated duplicate rows (e.g. 45m raw in a 3m session) | Capped to **3m** for that app |
| Session crosses hour boundary | Still one sum per app; no hour buckets |
| Last Screen Time banner | Always exact session timer, not app sum |

Each app is capped independently at wall-clock. Two apps could each show up to the full session length in one save (headline app total may exceed session time when several apps were active).

## Per-day Latest Summary

`DayActivitySummary` (in `SessionRepository`) rolls up all usage snapshots for the calendar day:

- **`totalSeconds`** — Sum of each snapshot's session timer (`totalSeconds` on save).
- **`sessionCount`** — Number of snapshots that day; title e.g. **Today (2 sessions)**.
- **`mergedApps`** — `SessionUsageHourMerge.mergeAppsHourAware`: **sum** each snapshot's capped per-app seconds per bundle (e.g. 11 sessions × 3m TikTok → **~33m** if each snapshot saved ~3m).

`SessionCoordinator` always drives the dashboard Latest Summary from `dayActivitySummary` after stop/refresh—not from the last session's apps alone.

## What we cannot promise

- Per-app minutes that exactly match session time when multiple apps were used.
- Foreground-only usage.
- Export or charts that match Settings → Screen Time for the full day.

We do **not** fetch `.daily` whole-day API for the chart. Per-app values are summed Apple estimates, capped per session at wall-clock, then summed across sessions for today.

## Parent-facing copy guide

**Principles:** Lead with what we measure well; don't blame Apple in the UI; avoid "API", "bucket", "EU"; one idea per line; Settings as optional truth.

| Moment | Example copy (implemented in `DashboardView.latestSummary`) |
|--------|--------------------------------------------------------------|
| Hero | **Session time (today): X** — "Measured while sessions were active." |
| Per-app section | **App usage (estimate)** — "From iOS Screen Time for today. Times are approximate." |
| Mismatch (>10%) | "That's normal. Session time is exact; app breakdown is Apple's estimate and can differ when several apps were used in one session." |
| Multi-session | **Today (2 sessions)** from `DayActivitySummary.periodTitle` |
| Empty apps | "App breakdown can take a minute after a session ends. Pull to refresh or check again shortly." |
| Settings | **See Apple's Screen Time** → opens Settings |
| Footer | "We track session length precisely. Per-app numbers are Apple's best estimate…" |
| Info (ⓘ) | Tooltip on Latest Summary: timer vs app estimate; multiple sessions add for today |

**Avoid:** "failed", "wrong", "bug", "limitation of our app", "data unavailable (EU)".

## Fetch timing

`ScreenTimeService.fetchUsage` runs **three** aggregate attempts with **2s / 4s / 6s** delays before each (always all three—no early exit when a single app hits 30s). The richest attempt by payload score is kept.

**Session stop** records the stop marker, runs that fetch loop while monitoring is still active, then `stopMonitoring()`, saves one upserted snapshot (wall-clock + apps), and updates Latest Summary.

**Pull to refresh** runs the same fetch for the last completed session when the snapshot has no app rows, upserts, and reloads the summary.

## Debugging

Use **Settings → Screen Time debug** (internal) to inspect pipeline logs: `raw=`, `bucket=`, `sessionCap=`, `agg=sum` on kept rows. Expect three `fetchUsage:attempt` lines then `fetchUsage:success`. Last Screen Time banner uses session timer; Latest Summary uses capped app totals summed across sessions.
