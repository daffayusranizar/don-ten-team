import FamilyControls
import ManagedSettings
import SwiftUI

struct ApplicationTokenIcon: View {
    let token: ApplicationToken?
    var size: CGFloat = 22

    var body: some View {
        Group {
            if let token {
                Label(token)
                    .labelStyle(.iconOnly)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.55))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
