import SwiftUI

struct AppUsageIconView: View {
    let bundleIdentifier: String
    var size: CGFloat = 14
    var cornerRadius: CGFloat = 3

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.accentColor.opacity(0.25))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.55))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(bundleIdentifier)
    }
}
