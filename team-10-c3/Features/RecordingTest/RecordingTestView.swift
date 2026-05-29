import SwiftUI
import ReplayKit

struct RecordingTestView: View {
    @StateObject private var recordingManager = RecordingManager.shared
    @State private var recordedPath: String?
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Backend Testing Screen")
                .font(.title)
                .bold()
            
            // Removed Screen Time Permission UI due to Apple Developer constraints
            
            // 2. Broadcast Picker
            VStack {
                Text("Screen Recording (1 FPS)")
                    .font(.headline)
                
                BroadcastPicker()
                    .frame(width: 60, height: 60)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // 3. Status View
            VStack(alignment: .leading, spacing: 10) {
                Text("Latest Recording Path:")
                    .font(.headline)
                
                if let path = recordedPath {
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("No recording found yet. Press the button above to start, and refresh when done.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Refresh Path") {
                    recordedPath = recordingManager.fetchLatestRecordedVideoPath()
                }
                .padding(.top, 5)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .onAppear {
            recordedPath = recordingManager.fetchLatestRecordedVideoPath()
        }
    }
}

// UIKit wrapper for RPSystemBroadcastPickerView
struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        // Must use a non-zero frame, otherwise the internal button collapses in SwiftUI
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        
        // IMPORTANT: Set this to the Bundle Identifier of your Broadcast Upload Extension
        // If this is wrong, the picker will show a list of all apps instead of auto-selecting ours.
        picker.preferredExtension = BroadcastConstants.extensionBundleID
        
        picker.showsMicrophoneButton = true
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

#Preview {
    RecordingTestView()
}
