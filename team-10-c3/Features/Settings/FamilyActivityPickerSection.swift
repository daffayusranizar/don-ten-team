import SwiftUI
import FamilyControls

struct FamilyActivityPickerSection: View {
    @State private var selection = FamilyActivitySelectionStore.load()
    @State private var isPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monitored Apps")
                .font(.system(size: 20, weight: .semibold))

            Text("Choose which apps count toward session screen time.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            PrimaryButton(
                title: "Choose Apps",
                size: .medium,
                systemImage: "apps.iphone",
                action: { isPickerPresented = true }
            )
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        .onChange(of: selection) { _, newValue in
            FamilyActivitySelectionStore.save(newValue)
        }
    }
}
