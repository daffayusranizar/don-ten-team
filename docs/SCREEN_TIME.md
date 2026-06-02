# Screen Time data in ParentGuide

This document explains how ParentGuide uses Apple’s Screen Time APIs, how we aggregate usage for parent sessions, and what parents should expect on the dashboard.

## What parents see

| Metric | Source | Accuracy |
|--------|--------|----------|
| **Session time (today)** | ParentGuide session timer (start/stop, pause-aware) | Exact for time the session was active |
| **App usage (estimate)** | iOS `activityData` for session windows, merged per day | Approximate; hourly buckets from Apple |
| **Settings → Screen Time** | Apple’s full-day view | Optional “ground truth” for the whole device |

Session time and per-app bars answer different questions. They will not always add up.

## Apple API limits

- **No per-minute per-app buckets** for arbitrary session windows. `DeviceActivityFilter` supports hourly, daily, and weekly segments only.
- **`totalActivityDuration` per application** is the main per-app signal inside a segment—not foreground-only minute tracking.
- **EU / data access**: On iOS 26.4+, reliable usage requires `AuthorizationCenter` status `approvedWithDataAccess` (not merely `approved`).
- **No Settings parity**: We cannot reproduce Settings → Screen Time totals inside a custom session chart.

## What ParentGuide uses

- **`DeviceActivityData.activityData`** only—no `DeviceActivityReport`, no report extension, no App Group export for usage charts.
- **Filter**: `hourly+session` built in `SessionActivityFilterBuilder` (session window clipped to hourly segment interval).
- **Noise**: `SessionUsageNoiseFilter` drops system/background bundles before display and persistence.

## Hour overlap + session cap (per session)

When a session stops, `DeviceActivityUsageAggregator` processes each overlapping activity segment:

1. **Session overlap** — Intersect segment interval with `[sessionStart, sessionStop)`.
2. **Hour normalize** — Clip that overlap to the calendar hour containing it (`Calendar.dateInterval(of: .hour, for:)`).
3. **Session cap (per row)** — `cappedSeconds = min(rawSeconds, overlapInHour, sessionWallClock)`; no multiplicative weighting.
4. **Same hour** — Key `(bundleId, hourBucketStart)`; **sum** capped row values, then **min(sum, hour overlap seconds)** for that bucket.
5. **Per app** — **Sum** across distinct hour keys, then `min(sum, sessionWallClock)` so one app cannot exceed session length.

| Case | Behavior |
|------|----------|
| Same app, same hour (duplicate segments) | **sum**, then **min(sum, hour overlap)** |
| Same app, different hours (session crosses hour boundary) | **sum** |
| Session timer in snapshot | Wall-clock elapsed at stop—not sum of apps |

## Per-day Latest Summary

`DayActivitySummary` (in `SessionRepository`) rolls up all usage snapshots for the calendar day:

- **`totalSeconds`** — Sum of each snapshot’s session timer (`totalSeconds` on save).
- **`sessionCount`** — Number of snapshots that day; title e.g. **Today (2 sessions)**.
- **`mergedApps`** — `SessionUsageHourMerge.mergeAppsHourAware`: for each snapshot, attribute its app rows to every calendar hour the **session interval** touches; **sum** per `(bundle, hour)` with hour overlap cap; **sum** hours per bundle.

`SessionCoordinator` always drives the dashboard Latest Summary from `dayActivitySummary` after stop/refresh—not from the last session’s apps alone.

## What we cannot promise

- Per-app minutes that exactly match session time.
- Foreground-only usage.
- Export or charts that match Settings → Screen Time for the full day.

We also do **not**: fetch `.daily` whole-day API for the chart, or proportionally scale all app totals to match session time. Per-app values use **min-cap** against overlap and session wall clock only.

## Parent-facing copy guide

**Principles:** Lead with what we measure well; don’t blame Apple in the UI; avoid “API”, “bucket”, “EU”; one idea per line; Settings as optional truth.

| Moment | Example copy (implemented in `DashboardView.latestSummary`) |
|--------|--------------------------------------------------------------|
| Hero | **Session time (today): X** — “Measured while sessions were active.” |
| Per-app section | **App usage (estimate)** — “From iOS Screen Time for today. Times are approximate.” |
| Mismatch (>10%) | “That’s normal. Session time is exact; app breakdown comes from Apple in hourly slices.” |
| Multi-session | **Today (2 sessions)** from `DayActivitySummary.periodTitle` |
| Empty apps | “App breakdown can take a minute after a session ends. Pull to refresh or check again shortly.” |
| Settings | **See Apple's Screen Time** → opens Settings |
| Footer | “We track session length precisely. Per-app numbers are Apple's best estimate…” |
| Info (ⓘ) | Tooltip on Latest Summary: timer vs hourly slices, same-hour dedup |

**Avoid:** “failed”, “wrong”, “bug”, “limitation of our app”, “data unavailable (EU)”.

## Debugging

- **Settings → Screen Time Debug** (`ScreenTimeDebugView`): filter labels, candidate payloads, I/O sections.
- **Console**: `[ScreenTime:…]` via `ScreenTimePipelineLogger` (filter build, fetch, RAW rows with `hourBucketStart`, `overlapCap`, `sessionCap`, `capped`, `aggregation=max|skip`).
- **NDJSON**: `AgentDebugLog` / pipeline `emit` locations documented in logger source.

### Verification checklist

1. **One session, one hour** — RAW log shows one `hourBucketStart`; `capped = min(raw, overlapCap, sessionCap)` (no `weight=`).
2. **One session, two hours** — Two hour keys; per-app total sums both.
3. **Two sessions, same hour, same day** — Day chart uses **max** for that app in the shared hour, not sum of both session values.
4. **Two sessions, different hours** — Day chart **sums** hour contributions.
5. **Latest Summary** — **Today (N sessions)** with session time = sum of session timers.

## References

- [DeviceActivity](https://developer.apple.com/documentation/deviceactivity) — filters and data policies
- [FamilyControls / AuthorizationCenter](https://developer.apple.com/documentation/familycontrols) — authorization including data access
- Apple Developer Forums — Screen Time API discussions (e.g. thread #722334)
- WWDC22 — Screen Time API session

## Key source files

| File | Role |
|------|------|
| `DeviceActivityUsageAggregator.swift` | Hour overlap + session cap + max-per-hour |
| `SessionUsageHourMerge.swift` | Hour helpers + day merge |
| `SessionActivityFilterBuilder.swift` | `hourly+session` filter only |
| `SessionRepository.swift` | `DayActivitySummary`, snapshots |
| `SessionCoordinator.swift` | Day-only Latest Summary |
| `DashboardView.swift` | Parent copy |
| `ScreenTimePipelineLogger.swift` | Pipeline + RAW logging |
