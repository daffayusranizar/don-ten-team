# Screen Time data in Kiddly

This document explains how Kiddly uses Apple's Screen Time APIs, how we aggregate usage for parent sessions, and what parents should expect on the dashboard.

## What parents see

| Metric | Source | Accuracy |
|--------|--------|----------|
| **Session time (today)** | Kiddly session timer (start/stop, pause-aware) | Exact for time the session was active |
| **Last Screen Time (banner)** | Parent session timer for the most recent session | Exact session length |
| **24h stacked chart + app list** | Live `activityData` per calendar hour for today's sessions | Approximate Apple estimates |
| **Settings → Screen Time** | Apple's full-day view | Optional “ground truth” for the whole device |

Session time and per-app bars answer different questions. They will not always add up.

## Apple API limits

- **No per-minute per-app buckets** for arbitrary session windows. `DeviceActivityFilter` supports hourly, daily, and weekly segments only.
- **`totalActivityDuration` per application** is the main per-app signal inside a segment—not foreground-only minute tracking.
- **EU / data access**: On iOS 26.4+, reliable usage requires `AuthorizationCenter` status `approvedWithDataAccess` (not merely `approved`). The app calls `ensureUsageAuthorization()` before chart fetch so Apple’s Screen Time permission sheet is shown when needed.
- **No Settings parity**: We cannot reproduce Settings → Screen Time totals inside a custom session chart.

## App blocking during sessions

When a parent session **starts**, Kiddly applies a **ManagedSettings** shield (`SessionAppShield` + `SessionShieldStore`):

- **Category policy**: shield all app categories except TikTok/YouTube tokens (`.all(except:)`).
- **Per-app blocklist**: shield every other installed app token from `FamilyActivityData.installedApplications`.
- **Web**: shield web domain categories (blocks most in-app Safari browsing).
- **Device Activity Monitor extension** (`DeviceActivityMonitorExtension`) re-applies shields when `DeviceActivityCenter.startMonitoring` fires `intervalDidStart`.

Shields clear on session stop and on app launch if no session is active.

- Requires **Screen Time / Family Controls** authorization on the device.
- Test on a **physical device**; the simulator does not enforce shields.
- In **Screen Time debug**, check App Group key `deviceActivityExtensionHeartbeat` after starting a session — should read `intervalDidStart` if the monitor extension ran.

## What Kiddly uses

- **`DeviceActivityData.activityData`** only—no `DeviceActivityReport`, no report extension, no App Group export for usage charts.
- **Filter**: One `activityData` query **per calendar hour** touched by any session that day (`SessionActivityFilterBuilder.filterForHour`), scoped to **TikTok and YouTube** via FamilyControls `ApplicationToken`s (`MonitoredApplicationTokens`).
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

## Partial-hour chart marking

Parents need to know when a bar’s **hour bucket** is wider than the time they actually ran a session. We mark those hours on the **Latest Summary** 24h stacked chart.

### What we built

| Piece | Role |
|-------|------|
| [`SessionUsageHourMerge`](team-10-c3/Services/ScreenTime/SessionUsageHourMerge.swift) | Computes which local hours (0–23) are “partial” from **parent session windows** (start/stop markers), not from Apple usage |
| [`HourlyStackedChartBuilder`](team-10-c3/Features/Dashboard/HourlyStackedChartBuilder.swift) | Sets `isPartialHour` on each chart segment from that hour set |
| [`HourlyChartDotPattern`](team-10-c3/Features/Dashboard/HourlyChartDotPattern.swift) | Tiled `ImagePaint` dot overlay on partial-hour bars (per app color) |
| [`DashboardView`](team-10-c3/Features/Dashboard/DashboardView.swift) | Applies pattern vs solid fill; shows caption when any hour is partial |
| [`SessionCoordinator`](team-10-c3/Features/Dashboard/SessionCoordinator.swift) | Passes session windows into the builder after daily fetch and during live session refresh |

**Definition — partial hour:** For a calendar hour, the **union** of all session overlaps with `[hourStart, hourEnd)` is shorter than that hour’s `DateInterval.duration` (uses real hour length, not a fixed 3600s, so DST is handled). A 1-second tolerance avoids rounding glitches.

**Examples:**

| Sessions in hour 9 | Marked partial? |
|--------------------|-----------------|
| 9:15–9:45 only | Yes (~30 min covered) |
| 9:00–9:30 and 9:30–10:00 | No (full hour covered together) |
| Active session, now 9:20, started 9:05 | Yes for hour 9 |
| Session exactly 9:00–10:00 | No for hour 9; yes for hour 10 if stop is exactly on the boundary |

**Data flow:**

```text
SessionWindow[] (markers / live window)
  → partialHourNumbers()
  → HourlyStackedChartBuilder.build(rows, sessions)
  → HourlyStackedChartSegment.isPartialHour
  → Chart: solid fill vs HourlyChartDotPattern.fill
```

**What the dots mean for parents:** “We only had a parent session for **part** of this clock hour.” The **height** of the stack is still Apple’s estimated usage for the **whole** hourly query (TikTok/YouTube in that bucket)—not clipped to session length.

**Parent-facing copy** (shown only when at least one partial hour has data):

> Dotted bars: the parent session covered only part of that hour. App usage is still Apple's estimate for the whole hour bucket.

### Limitations

**Session coverage vs usage data**

- Dots indicate **timer window coverage**, not whether Apple’s numbers are incomplete or wrong.
- We still fetch one **full calendar hour** from `DeviceActivityFilter` per touched hour. Partial marking does **not** narrow the API query to the session overlap interval.
- Bar **heights are not scaled** to “minutes session was active in this hour.” A 10-minute session in hour 9 can still show a tall stack if Apple reports high `totalActivityDuration` for that hour.

**Detection edge cases**

- Uses **marker start/stop** (or snapshot fallback windows) for the day. Pauses affect the **session timer** headline, but live refresh builds `SessionWindow(startAt, stopAt: Date())` without subtracting paused wall time—partial-hour math for an in-progress session can treat paused clock time as “covered.”
- Hour identity is **0–23 only** on the chart axis. The dashboard day view does not plot two different calendar dates in one chart; if that were added, partial flags would need `Date` + hour, not hour alone.
- Hours with **no app usage rows** never get a bar, so there is no dot—even if the session touched that hour with zero TikTok/YouTube usage.

**Visual / UX**

- Pattern is a **tiled image** per app color (`ImagePaint`), not a separate legend entry. The legend still shows solid app colors; parents rely on the caption to learn what dots mean.
- Very small stacks may show a faint or hard-to-see pattern; accessibility does not add a non-visual-only alternative beyond the caption.
- If `ImageRenderer` fails, fallback is a **solid** color tile (no dots) for that palette entry.

**Product / API (unchanged by this feature)**

- Still **no per-minute** per-app breakdown; hourly buckets only.
- Still **TikTok and YouTube** (monitored tokens) in chart filters—not all apps on the device.
- Per-app totals still **won’t match** session timer when multiple apps or system noise appear; dots don’t fix that mismatch.

## Per-day Latest Summary (timers)

`DayActivitySummary` (in `SessionRepository`) rolls up timer snapshots for the calendar day:

- **`totalSeconds`** — Sum of each snapshot's session timer.
- **`sessionCount`** — Number of snapshots that day; title e.g. **Today (2 sessions)**.

Per-app chart and list data come from the **live hourly fetch**, not from the database.

## What we cannot promise

- Per-app minutes that exactly match session time when multiple apps were used.
- Foreground-only usage.
- Export or charts that match Settings → Screen Time for the full day.
- Partial-hour dots implying Apple only measured the session overlap (we still query the full hour).
- Chart bar height proportional to “fraction of hour the session ran.”

We do **not** fetch `.daily` whole-day API for the chart.

## Parent-facing copy guide

| Moment | Example copy |
|--------|--------------|
| Hero | **Session time (today): X** — "Measured while sessions were active." |
| Per-app section | **App usage (estimate)** — "TikTok and YouTube only. From iOS Screen Time for today. Times are approximate." |
| Loading chart | "Loading app usage…" |
| Empty apps | "No app usage for this period yet. End a session or pull to refresh." |
| Multi-session | **Today (2 sessions)** from `DayActivitySummary.periodTitle` |
| Partial-hour chart | **Dotted bars:** session covered only part of that hour; usage is still Apple’s estimate for the full hour bucket |

## Fetch timing

- **Session stop** — Record stop marker, `stopMonitoring()`, save timer snapshot only (fast). Chart loads asynchronously.
- **Dashboard / pull to refresh** — `fetchHourlyUsageForSessions`: single pass, one query per union hour (no 2s/4s/6s retry loop).
- **Debug** — `fetchUsage` (single session) still uses triple-attempt aggregation for diagnostics.

## Debugging

Use **Settings → Screen Time debug** to inspect pipeline logs: `hourly+` filter labels, `agg=max` per hour. Last Screen Time banner uses session timer; Latest Summary chart uses live hourly data across today's sessions.
