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
    @State var showKidSessionActive: Bool = false
    @State var showSessionEnd: Bool = false
    @State var addingTime: Bool = false
    @State private var showScreenTimeAuthAlert = false
    @State private var pendingKidSessionAfterScreenTimeAuth = false
    @State private var showOnboardingPage: Bool = false
    @AppStorage("screenTimeAuthPromptDismissed") private var screenTimeAuthPromptDismissed = false
    @AppStorage("screenTimeUsagePromptDismissed") private var screenTimeUsagePromptDismissed = false
    @Environment(\.scenePhase) private var scenePhase
    
    private var selectedChildExists: Bool {
        profileViewModel.selectedChild != nil
    }

    @ViewBuilder
    private var dashboardMainContent: some View {
        if profileViewModel.selectedChild == nil {
            dashboardEmptyState(
                hasChildren: !profileViewModel.children.isEmpty,
                onAddChild: { showAddChild = true }
            )
        } else if sessionCoordinator.isSessionActive && kidSessionViewModel.isSessionActive {
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
    }

    @ViewBuilder
    private var screenTimeBannerSection: some View {
        if selectedChildExists && shouldShowScreenTimeBanner {
            ScreenTimePermissionBanner(
                gaps: familyControlsAuth.missingPermissions,
                statusDescription: familyControlsAuth.authorizationStatusDescription,
                canRequestUsageAccess: !familyControlsAuth.isUsageDataEntitlementMissing,
                onEnable: { showScreenTimeAuthAlert = true }
            )
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if selectedChildExists,
           let screenTimeError = sessionCoordinator.loadError {

            Button {
                if familyControlsAuth.needsPermissionPrompt
                    || familyControlsAuth.needsUsagePermissionPrompt {
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
    }

    @ViewBuilder
    private var summarySection: some View {
        if selectedChildExists {
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

    var body: some View {
        @Bindable var profileViewModel = profileViewModel
        @Bindable var sessionCoordinator = sessionCoordinator
        
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 70)

                    dashboardMainContent
                    screenTimeBannerSection
                    errorSection
                    summarySection
                }
                .padding(.horizontal, 30)
                .padding(.vertical)
                .foregroundStyle(.textPrimary)

                HStack {
                    PrimaryDropdown(
                        selectedChild: Binding(
                            get: { profileViewModel.selectedChild },
                            set: { newChild in
                                guard !kidSessionViewModel.locksChildSelection else { return }
                                profileViewModel.selectedChild = newChild
                            }
                        ),
                        allowsSelection: !kidSessionViewModel.locksChildSelection,
                        onAddChild: { showAddChild = true }
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
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showOnboardingPage) {
            OnboardingView()
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .childProfileFormSheet(isPresented: $showAddChild) { child in
            profileViewModel.handleChildSaved(child)
            profileViewModel.selectedChild = child
        }
        .navigationDestination(isPresented: $showKidSession) {
            SessionSetupView()
                .onAppear {
                    kidSessionViewModel.syncSelectedChild(from: profileViewModel)
                }
        }
        .navigationDestination(isPresented: $showKidSessionActive) {
            KidSessionActiveView()
        }
        .navigationDestination(isPresented: $showSessionEnd) {
            SessionResultView {
                showSessionEnd = false
                kidSessionViewModel.resetAfterEndScreen()
            }
        }
        .onAppear {
            profileViewModel.loadChildren()
            presentScreenTimePromptIfNeeded()
            if let child = profileViewModel.selectedChild {
                sessionCoordinator.refreshAfterChildSwitch(for: child)
            }
            Task { @MainActor in
                await Task.yield()
                familyControlsAuth.refreshAuthorizationStatus()
                kidSessionViewModel.reconcilePersistedSession(profileViewModel: profileViewModel)
            }
            showOnboardingPage = profileViewModel.children.isEmpty
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            sessionCoordinator.refreshAfterChildSwitch(for: profileViewModel.selectedChild)
            Task { @MainActor in
                await Task.yield()
                familyControlsAuth.refreshAuthorizationStatus()
                kidSessionViewModel.reconcilePersistedSession(profileViewModel: profileViewModel)
            }
        }
        .onChange(of: profileViewModel.children.count) { _, _ in
            sessionCoordinator.refresh(for: profileViewModel.selectedChild)
        }
        .screenTimeAuthorizationAlert(
            isPresented: $showScreenTimeAuthAlert,
            onAuthorized: {
                if familyControlsAuth.needsPermissionPrompt == false {
                    screenTimeAuthPromptDismissed = true
                }
                if profileViewModel.selectedChild != nil {
                    sessionCoordinator.refresh(for: profileViewModel.selectedChild)
                }
                if pendingKidSessionAfterScreenTimeAuth {
                    pendingKidSessionAfterScreenTimeAuth = false
                    showKidSession = true
                }
            },
            onDismissWithoutAuth: {
                pendingKidSessionAfterScreenTimeAuth = false
                if familyControlsAuth.needsPermissionPrompt {
                    screenTimeAuthPromptDismissed = true
                } else if familyControlsAuth.needsUsagePermissionPrompt {
                    screenTimeUsagePromptDismissed = true
                }
            }
        )
        .onChange(of: profileViewModel.selectedChild?.id) { _, _ in
            guard !kidSessionViewModel.locksChildSelection else { return }
            sessionCoordinator.refreshAfterChildSwitch(for: profileViewModel.selectedChild)
        }
        .onChange(of: showKidSession) { _, isShowing in
            if !isShowing {
                kidSessionViewModel.syncSelectedChild(from: profileViewModel)
                sessionCoordinator.refresh(for: profileViewModel.selectedChild)
            }
        }
        .onChange(of: kidSessionViewModel.phase) { _, newPhase in
            switch newPhase {
            case .idle:
                showKidSessionActive = false
                showSessionEnd = false
                sessionCoordinator.refresh(for: profileViewModel.selectedChild)
            case .active:
                showSessionEnd = false
                showKidSessionActive = true
            case .finished:
                showKidSessionActive = false
                showSessionEnd = true
                sessionCoordinator.refresh(for: profileViewModel.selectedChild)
            }
        }
        .sheet(isPresented: $addingTime) {
            addTimeView(addingTime: $addingTime) { seconds in
                sessionCoordinator.addAdditionalTime(seconds: seconds)
            }
            .presentationDetents([.fraction(0.5), .large])
        }
    }

    private var shouldShowScreenTimeBanner: Bool {
        if familyControlsAuth.needsPermissionPrompt {
            return true
        }
        return familyControlsAuth.needsUsagePermissionPrompt && !screenTimeUsagePromptDismissed
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
            showAlert: {
                pendingKidSessionAfterScreenTimeAuth = true
                showScreenTimeAuthAlert = true
            },
            onAuthorized: { showKidSession = true }
        )
    }

    // MARK: Empty State
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


#Preview {
    let repository = InMemoryChildRepository()
    let profileViewModel = ProfileViewModel(childRepository: repository)
    
    NavigationStack {
        DashboardView()
            .environment(\.childRepository, repository)
            .environment(\.profileViewModel, profileViewModel)
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
