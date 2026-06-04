//
//  SessionRecordingFilename.swift
//  Shared between main app and ScreenRecorderExtension
//

import Foundation

public enum SessionRecordingFilename {
    public static func mp4Name(sessionId: UUID) -> String {
        "recording_\(sessionId.uuidString.lowercased()).mp4"
    }
}
