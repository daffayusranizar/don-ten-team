import ReplayKit
import UIKit

/// Minimal setup UI — immediately hands off to the upload extension.
/// The system uses this extension's AppIcon in the broadcast picker.
final class BroadcastSetupViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        userDidFinishSetup()
    }

    @objc private func userDidFinishSetup() {
        let broadcastURL = URL(string: "kiddly-broadcast://start")!
        extensionContext?.completeRequest(withBroadcast: broadcastURL, setupInfo: nil)
    }
}
