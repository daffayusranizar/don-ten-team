ParentGuide/
│
├── App/                    Entry point, routing, and dependency setup
│
├── DesignSystem/           Shared UI components and visual tokens
│                           (colors, typography, reusable views like timer ring, alarm overlay)
│
├── Features/               One folder per screen group
│   ├── Onboarding/         First-time parent setup
│   ├── Dashboard/          Home screen — shows all children at a glance
│   ├── KidSession/         The core handoff flow — setup, countdown, alarm
│   ├── Profiles/           Manage children + browse their session history
│   ├── Rules/              Set screen time schedules and category limits       [P2]
│   ├── WeeklySummary/      Weekly digest of what the child watched/played      [P2]
│   ├── Guidance/           Parenting advice, response scripts, offline ideas   [P2]
│   ├── Privacy/            What's collected, audit log, transparency           [P3]
│   └── Negotiation/        Child requests extra time, parent approves/declines [P4]
│
├── Models/                 All data models stored on device (SwiftData)
│                           (child profiles, sessions, rules, summaries, guidance)
│
├── Services/               All business logic
│                           (session timer, Face ID, notifications, ML pipeline, rules engine)
│
├── Repositories/           Read/write data to and from SwiftData
│
├── MLEngine/               The AI content analysis engine
│                           (copied from existing project — MobileCLIP, Whisper, Vision, etc.)
│
└── Shared/                 Files shared between the main app and the broadcast extension
                            (recording constants, handoff, video writer)


Extensions/
├── BroadcastUpload/        Captures the screen while the child uses the device  [P1]
├── DeviceActivityMonitor/  Fires when a screen time limit is reached             [P2]
├── DeviceActivityReport/   Shows usage data inside iOS Screen Time settings      [P2]
└── ShieldConfiguration/    Custom "time's up" screen shown to the child          [P2]