import SwiftUI

struct FamilyActivityPickerSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monitored Apps")
                .font(.system(size: 20, weight: .semibold))

            Text("During a parent session, only TikTok and YouTube can be opened. Other apps are blocked until the session ends. Usage tracking is limited to those two apps.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label("TikTok", systemImage: "play.rectangle.fill")
                Label("YouTube", systemImage: "play.rectangle.fill")
            }
            .font(.system(size: 15, weight: .medium))
        }
    }
}
