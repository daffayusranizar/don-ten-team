//
//  DashboardView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Child list + active session banner

import SwiftUI
import Charts
import UIKit

struct DashboardView: View {
    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.sessionCoordinator) private var sessionCoordinator
    @Environment(\.kidSessionViewModel) private var kidSessionViewModel
    @Environment(\.familyControlsAuth) private var familyControlsAuth
    @State var showSettings: Bool = false
    @State var showAddChild: Bool = false
    @State var showKidSession: Bool = false
    @State var showSessionEnd: Bool = false
    @State var addingTime: Bool = false
    @State private var showScreenTimeAuthAlert = false
    @AppStorage("screenTimeAuthPromptDismissed") private var screenTimeAuthPromptDismissed = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var profileViewModel = profileViewModel
        @Bindable var sessionCoordinator = sessionCoordinator

        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 70)

                    if profileViewModel.selectedChild == nil {
                        dashboardEmptyState(
                            hasChildren: !profileViewModel.children.isEmpty,
                            onAddChild: { showAddChild = true }
                        )
                    } else if sessionCoordinator.isSessionActive {
                        currentScreenTimeView(
                            coordinator: sessionCoordinator,
                            addingTime: $addingTime,
                            onStop: {
                                kidSessionViewModel.endSessionEarly()
                            }
                        )
                    } else {
                        lastScreenTimeView(coordinator: sessionCoordinator) {
                            beginKidSessionFlow()
                        }
                    }

                    if profileViewModel.selectedChild != nil,
                       familyControlsAuth.needsPermissionPrompt {
                        ScreenTimePermissionBanner(
                            gaps: familyControlsAuth.missingPermissions,
                            statusDescription: familyControlsAuth.authorizationStatusDescription,
                            onEnable: { showScreenTimeAuthAlert = true }
                        )
                    }

                    if profileViewModel.selectedChild != nil,
                       let screenTimeError = sessionCoordinator.loadError {
                        Button {
                            if familyControlsAuth.needsPermissionPrompt {
                                showScreenTimeAuthAlert = true
                            }
                        } label: {
                            Text(screenTimeError)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.orange.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    if profileViewModel.selectedChild != nil {
                        latestSummary(
                            periodTitle: sessionCoordinator.summaryPeriodTitle,
                            hourlySegments: sessionCoordinator.summaryHourlyChartSegments,
                            topApps: sessionCoordinator.hasSummaryData
                                ? sessionCoordinator.summaryTopApps
                                : [],
                            isUpdating: sessionCoordinator.isLoadingSummaryUsage
                                || sessionCoordinator.isRefreshingPartialUsage,
                            sessionElapsedSeconds: sessionCoordinator.summarySessionElapsedSeconds,
                            screenTimeAppTotalSeconds: sessionCoordinator.summaryScreenTimeAppTotalSeconds,
                            showsTotalsMismatch: sessionCoordinator.showsScreenTimeTotalsMismatch
                        )
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical)
                .foregroundStyle(.textPrimary)

                HStack {
                    PrimaryDropdown(
                        selectedChild: $profileViewModel.selectedChild
                    )

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .semibold))
                            .padding()
                            .background(
                                Circle()
                                    .fill(.uiSurface)
                            )
                    }
                }
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, 30)
                .padding(.vertical)
                .zIndex(1000)
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .navigationDestination(isPresented: $showAddChild) {
            ProfileFormView { child in
                profileViewModel.handleChildSaved(child)
            }
        }
        .navigationDestination(isPresented: $showKidSession) {
            SessionSetupView()
                .onAppear {
                    kidSessionViewModel.syncSelectedChild(from: profileViewModel)
                }
        }
        .navigationDestination(isPresented: $showSessionEnd) {
            SessionResultView(
                isAnalyzing: kidSessionViewModel.isAnalyzingSession,
                result: kidSessionViewModel.sessionAnalysisResult,
                errorMessage: kidSessionViewModel.sessionAnalysisError,
                showsRecordingHint: !kidSessionViewModel.sessionIncludedScreenRecording
            ) {
                showSessionEnd = false
                kidSessionViewModel.resetAfterEndScreen()
            }
        }
        .onAppear {
            familyControlsAuth.refreshAuthorizationStatus()
            profileViewModel.loadChildren()
            sessionCoordinator.refresh(for: profileViewModel.selectedChild)
            presentScreenTimePromptIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            familyControlsAuth.refreshAuthorizationStatus()
            sessionCoordinator.refresh(for: profileViewModel.selectedChild)
        }
        .onChange(of: profileViewModel.children.count) { _, _ in
            sessionCoordinator.refresh(for: profileViewModel.selectedChild)
        }
        .screenTimeAuthorizationAlert(
            isPresented: $showScreenTimeAuthAlert,
            onAuthorized: {
                if profileViewModel.selectedChild != nil {
                    showKidSession = true
                }
            },
            onDismissWithoutAuth: {
                screenTimeAuthPromptDismissed = true
            }
        )
        .onChange(of: profileViewModel.selectedChild?.id) { _, _ in
            AgentDebugLog.relayAppGroupLogsToIngest()
            sessionCoordinator.refresh(for: profileViewModel.selectedChild)
        }
        .onChange(of: showKidSession) { _, isShowing in
            if !isShowing {
                kidSessionViewModel.syncSelectedChild(from: profileViewModel)
                sessionCoordinator.refresh(for: profileViewModel.selectedChild)
            }
        }
        .onChange(of: kidSessionViewModel.isSessionComplete) { _, isComplete in
            if isComplete {
                showSessionEnd = true
            }
        }
        .sheet(isPresented: $addingTime) {
            addTimeView(addingTime: $addingTime) { seconds in
                sessionCoordinator.addAdditionalTime(seconds: seconds)
            }
            .presentationDetents([.fraction(0.5), .large])
        }
    }

    private func presentScreenTimePromptIfNeeded() {
        guard profileViewModel.selectedChild != nil,
              !screenTimeAuthPromptDismissed else {
            return
        }
        familyControlsAuth.refreshAuthorizationStatus()
        guard familyControlsAuth.needsPermissionPrompt else { return }
        showScreenTimeAuthAlert = true
    }

    private func beginKidSessionFlow() {
        ScreenTimePermissionGate.runIfAuthorized(
            auth: familyControlsAuth,
            showAlert: { showScreenTimeAuthAlert = true },
            onAuthorized: { showKidSession = true }
        )
    }

    @ViewBuilder
    private func dashboardEmptyState(hasChildren: Bool, onAddChild: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            Image(systemName: hasChildren ? "person.crop.circle" : "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.primaryMediumBlue)

            Text(hasChildren ? "No child selected" : "No children yet")
                .font(.system(size: 22, weight: .semibold))

            Text(
                hasChildren
                    ? "Choose a child from the menu above to see screen time and session summaries."
                    : "Add your first child profile to start tracking screen time."
            )
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            if !hasChildren {
                PrimaryButton(
                    title: "Add Child",
                    size: .medium,
                    systemImage: "plus",
                    action: onAddChild
                )
                .padding(.top, 8)
            }

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

}

// MARK: Latest Summary
@ViewBuilder
func latestSummary(
    periodTitle: String,
    hourlySegments: [HourlyStackedChartSegment],
    topApps: [AppUsageRow],
    isUpdating: Bool = false,
    sessionElapsedSeconds: Int = 0,
    screenTimeAppTotalSeconds: Int = 0,
    showsTotalsMismatch: Bool = false
) -> some View {
    VStack(alignment: .leading) {
        HStack {
            Text("Latest Summary")
                .font(.system(size: 22, weight: .semibold))
            Spacer()
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(
                    "ParentGuide counts session minutes with a timer. The chart stacks estimated per-app Screen Time by hour for today."
                )
        }

        VStack(alignment: .center, spacing: 15) {
            Text(periodTitle)
                .font(.system(size: 18, weight: .semibold))

            if HourlyStackedChartBuilder.hasChartData(hourlySegments) {
                hourlyStackedAppChart(segments: hourlySegments)
                if hourlySegments.contains(where: \.isPartialHour) {
                    Text(
                        "Dotted bars: the parent session covered only part of that hour. App usage is still Apple's estimate for the whole hour bucket."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            } else if isUpdating {
                summaryEmptyState(message: "Loading app usage…")
            } else {
                summaryEmptyState(
                    message: "No app usage for this period yet. End a session or pull to refresh."
                )
            }

            mostUsedApps(topApps: topApps)

            if sessionElapsedSeconds > 0 {
                Text("Session time (today): \(DurationFormatting.compact(seconds: sessionElapsedSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Measured while sessions were active.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if screenTimeAppTotalSeconds > 0 {
                Text("App usage (estimate): \(DurationFormatting.compact(seconds: screenTimeAppTotalSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("From iOS Screen Time for today. Times are approximate.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showsTotalsMismatch {
                Text("That's normal. Session time is exact; app breakdown is Apple's estimate and can differ when several apps were used in one session.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                Text("See Apple's Screen Time")
                    .font(.caption.weight(.medium))
            }

            Text("We track session length precisely. Per-app numbers are Apple's best estimate for the time window—not minute-by-minute.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 30)
        .background(.decorativeSkyBlue.opacity(0.13))
        .clipShape(
            RoundedRectangle(cornerRadius: 15)
        )
    }
    .padding(.top, 30)
}

// MARK: 24-hour stacked app usage
@ViewBuilder
func hourlyStackedAppChart(segments: [HourlyStackedChartSegment]) -> some View {
    let legendApps = Dictionary(
        segments.map { ($0.bundleIdentifier, $0) },
        uniquingKeysWith: { first, _ in first }
    )
    .values
    .sorted { $0.appDisplayName.localizedCaseInsensitiveCompare($1.appDisplayName) == .orderedAscending }
    let appNames = legendApps.map(\.appDisplayName)
    let legendColors = legendApps.map(\.color)

    Chart(segments) { segment in
        BarMark(
            x: .value("Hour", segment.hour),
            y: .value("Seconds", segment.durationSeconds)
        )
        .foregroundStyle(hourlyBarForegroundStyle(segment))
    }
    .chartForegroundStyleScale(domain: appNames, range: legendColors)
    .chartXScale(domain: 0...23)
    .chartXAxis {
        AxisMarks(values: [0, 6, 12, 18]) { value in
            if let hour = value.as(Int.self) {
                AxisValueLabel(hourAxisLabel(hour))
            }
            AxisTick()
        }
    }
    .chartYAxis {
        AxisMarks(position: .leading) { value in
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text(DurationFormatting.compact(seconds: Int(number.rounded())))
                }
            }
            AxisTick()
        }
    }
    .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
    .chartPlotStyle { plotArea in
        plotArea.border(.clear)
    }
    .padding()
    .background(.uiBackground)
    .clipShape(RoundedRectangle(cornerRadius: 15))
}

private func hourlyBarForegroundStyle(_ segment: HourlyStackedChartSegment) -> AnyShapeStyle {
    if segment.isPartialHour {
        AnyShapeStyle(
            HourlyChartDotPattern.fill(base: segment.color, cacheKey: segment.colorName)
        )
    } else {
        AnyShapeStyle(segment.color)
    }
}

private func hourAxisLabel(_ hour: Int) -> String {
    switch hour {
    case 0: return "12a"
    case 1..<12: return "\(hour)a"
    case 12: return "12p"
    default: return "\(hour - 12)p"
    }
}

// MARK: Most Used Apps
@ViewBuilder
func mostUsedApps(topApps: [AppUsageRow]) -> some View {
    VStack {
        HStack {
            Text("App usage (estimate)")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
        }

        VStack {
            if topApps.isEmpty {
                summaryEmptyState(message: "No app usage recorded for this period.")
            } else {
                ForEach(topApps) { app in
                    AppUsageListRow(app: app)
                }
            }
        }
    }
    .padding()
    .background(.uiBackground)
    .clipShape(
        RoundedRectangle(cornerRadius: 15)
    )
}

@ViewBuilder
private func summaryEmptyState(message: String) -> some View {
    Text(message)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .background(.uiBackground)
        .clipShape(RoundedRectangle(cornerRadius: 15))
}

@ViewBuilder
private func sessionControlButton(
    systemName: String,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.primaryMediumBlue)
            .frame(width: 40, height: 40)
            .background(.white, in: Circle())
    }
    .buttonStyle(.plain)
}

// MARK: Current Screen Time (active session only)
@ViewBuilder
func currentScreenTimeView(
    coordinator: SessionCoordinator,
    addingTime: Binding<Bool>,
    onStop: @escaping () -> Void
) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Current Screen Time")
            .font(.system(size: 20, weight: .semibold))

        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(coordinator.formattedSessionRemaining) left")
                    .font(.system(size: 34, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("Used · \(coordinator.formattedSessionElapsed)")
                    .font(.system(size: 14, weight: .medium))
                    .opacity(0.85)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                sessionControlButton(systemName: "stop.fill", action: onStop)

                sessionControlButton(
                    systemName: coordinator.isSessionPaused ? "play.fill" : "pause.fill"
                ) {
                    withAnimation(.snappy) {
                        coordinator.togglePause()
                    }
                }
            }
            .fixedSize()
        }

        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .foregroundStyle(.white)

                Capsule()
                    .frame(width: max(0, geometry.size.width * coordinator.sessionProgress))
                    .foregroundStyle(.primaryTeal)
            }
        }
        .frame(height: 11)

        Text("Time Limit \(coordinator.formattedVerboseTimeLimit)")
            .font(.system(size: 10, weight: .regular))

        screenTimeActionButton(title: "Add More Time") {
            addingTime.wrappedValue = true
        }
        .padding(.top, 4)
    }
    .padding(.horizontal, 27)
    .padding(.vertical, 25)
    .foregroundStyle(.white)
    .background(.primaryMediumBlue)
    .clipShape(RoundedRectangle(cornerRadius: 25.6))
    .padding(.top, 30)
}

// MARK: Last Screen Time (session ended or no session today)
@ViewBuilder
func lastScreenTimeView(
    coordinator: SessionCoordinator,
    onStartSession: @escaping () -> Void
) -> some View {
    let hasData = coordinator.latestTotalSeconds > 0
    let total = hasData
        ? coordinator.formattedLatestBannerTotal
        : "—"

    let progressLabel: String = {
        if hasData {
            return "\(Int(coordinator.latestBannerProgress * 100))% of the session"
        }
        return "Start a session to track screen time"
    }()

    screenTimeBannerView(
        title: "Last Screen Time",
        total: total,
        progress: hasData ? coordinator.latestBannerProgress : 0,
        progressLabel: progressLabel
    ) {
        screenTimeActionButton(title: "Start Session", action: onStartSession)
    }
}

@ViewBuilder
private func screenTimeActionButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(.white))
    }
    .buttonStyle(.plain)
}

@ViewBuilder
private func screenTimeBannerView<Footer: View>(
    title: String,
    total: String,
    progress: Double,
    progressLabel: String,
    @ViewBuilder footer: () -> Footer = { EmptyView() }
) -> some View {
    VStack(alignment: .leading, spacing: 15) {
        Text(title)
            .font(Font.system(size: 24, weight: .semibold))

        Text("Total")

        Text(total)
            .font(Font.system(size: 40, weight: .semibold))

        VStack(alignment: .leading) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .foregroundStyle(.white)

                    Capsule()
                        .frame(width: geometry.size.width * progress)
                        .foregroundStyle(.primaryTeal)
                }
            }
            .frame(height: 12)

            Text(progressLabel)
        }

        footer()
    }
    .padding(.horizontal, 30)
    .padding(.vertical, 25)
    .foregroundStyle(.white)
    .background(.primaryMediumBlue)
    .clipShape(
        RoundedRectangle(cornerRadius: 25)
    )
    .padding(.top, 30)
}

// MARK: Additional Time Sheet View
func addTimeView(
    addingTime: Binding<Bool>,
    onAdd: @escaping (Int) -> Void
) -> some View {
    @State var hours = 0
    @State var minutes = 25 // defaults to 25 minutes for adding
    @State var seconds = 0

    // total time added as seconds
    var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    return VStack(alignment: .center) {
        // top bar
        ZStack {
            HStack {
                Button {
                    addingTime.wrappedValue = false
                } label: {
                    Image(systemName: "chevron.left")
                        .padding(20)
                }
                .glassEffect(in: Circle())

                Spacer()
            }

            Text("Add Additional Time")
                .font(.system(size: 20, weight: .semibold))
        }

        // time adder
        HStack {
            Picker("Hours", selection: $hours) {
                ForEach(0..<24) { hour in
                    Text("\(hour) h").tag(hour)
                }
            }

            Picker("Minutes", selection: $minutes) {
                ForEach(0..<60) { minute in
                    Text("\(minute) m").tag(minute)
                }
            }

            Picker("Seconds", selection: $seconds) {
                ForEach(0..<60) { second in
                    Text("\(second) s").tag(second)
                }
            }
        }
        .pickerStyle(.wheel)

        PrimaryButton(
            title: "Add Time",
            size: .large,
            action: {
                onAdd(totalSeconds)
                addingTime.wrappedValue = false
            }
        )
        .padding(.top, 20)
    }
    .padding()
}

#Preview {
    NavigationStack {
        DashboardView()
            .environment(\.profileViewModel, ProfileViewModel(childRepository: InMemoryChildRepository()))
            .environment(\.sessionCoordinator, SessionCoordinator(
                sessionRepository: InMemorySessionRepository(),
                screenTimeService: ScreenTimeService(),
                familyControlsAuth: PreviewFamilyControlsAuthService()
            ))
            .environment(\.kidSessionViewModel, KidSessionViewModel(
                sessionCoordinator: SessionCoordinator(
                    sessionRepository: InMemorySessionRepository(),
                    screenTimeService: ScreenTimeService(),
                    familyControlsAuth: PreviewFamilyControlsAuthService()
                )
            ))
    }
}
