import FamilyControls
import SwiftUI

struct FamilyActivityPickerSection: View {
    @Environment(\.familyControlsAuth) private var familyControlsAuth
    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false

    var onRequireScreenTimeAuth: () -> Void = {}
    var onSelectionChanged: ((FamilyActivitySelection) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allowed Apps")
                .font(.system(size: 20, weight: .semibold))

            Text(
                "During a session, only the apps you choose here stay open. Everything else is blocked until the session ends."
            )
            .font(.system(size: 14))
            .foregroundStyle(.secondary)

            PrimaryButton(
                title: pickerButtonTitle,
                size: .medium,
                systemImage: "apps.iphone.badge.plus",
                action: presentPicker
            )
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)

            selectionStatus
        }
        .onAppear {
            selection = FamilyActivitySelectionStore.load()
            onSelectionChanged?(selection)
        }
        .onChange(of: selection) { _, newValue in
            FamilyActivitySelectionStore.save(newValue)
            onSelectionChanged?(newValue)
        }
    }

    private var pickerButtonTitle: String {
        let count = selection.applicationTokens.count
        if count == 0 {
            return "Choose Allowed Apps"
        }
        return "Edit Allowed Apps (\(count))"
    }

    private func presentPicker() {
        familyControlsAuth.refreshAuthorizationStatus()
        guard familyControlsAuth.isAuthorized else {
            onRequireScreenTimeAuth()
            return
        }
        isPickerPresented = true
    }

    @ViewBuilder
    private var selectionStatus: some View {
        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count

        if !familyControlsAuth.isAuthorized {
            Text("Enable Screen Time below before choosing apps.")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
        } else if appCount >= 2 {
            Label("\(appCount) apps selected — ready for sessions", systemImage: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.green)
        } else if appCount == 1 {
            Label("1 app selected — ready for sessions", systemImage: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.green)
        } else if categoryCount > 0 {
            Label("Select individual apps, not categories only", systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
        } else {
            Label("No apps selected — required before starting a session", systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
        }
    }
}
