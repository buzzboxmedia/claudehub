# ClaudeHub iOS

iPhone companion app for ClaudeHub - monitor sessions and send quick replies.

## Features

- **Dashboard**: See waiting sessions, recent activity, project overview
- **Projects**: Browse all projects and sessions
- **Waiting Tab**: Quick access to sessions needing input (with badge)
- **Quick Reply**: Send "yes", "no", "continue" etc. to Mac via CloudKit
- **Session Detail**: View logs, mark complete, see summaries

## Setup in Xcode

1. Create new iOS App project in Xcode
   - Product Name: `ClaudeHubIOS`
   - Organization: `com.buzzbox`
   - Interface: SwiftUI
   - Storage: None (we add SwiftData manually)

2. Delete the auto-generated files and add these source files

3. Add capabilities:
   - **iCloud** → CloudKit → container: `iCloud.com.buzzbox.claudehub`
   - **Push Notifications**
   - **Background Modes** → Remote notifications

4. Build and run

## Architecture

```
ClaudeHubIOS/
├── ClaudeHubIOSApp.swift    # Main app + ModelContainer
├── ContentView.swift         # Tab navigation
├── Models/                   # Shared with macOS (copy)
│   ├── Project.swift
│   ├── Session.swift
│   ├── ProjectGroup.swift
│   └── ProjectCategory.swift
├── Views/
│   ├── DashboardView.swift   # Home tab
│   ├── ProjectsView.swift    # Projects list
│   ├── ProjectDetailView.swift
│   ├── SessionDetailView.swift
│   ├── WaitingView.swift     # Waiting tab
│   └── IOSSettingsView.swift
└── Services/
    └── QuickReplyService.swift  # CloudKit communication
```

## Quick Reply Flow

1. iOS creates `QuickReply` record in CloudKit
2. Mac subscribes to `QuickReply` record type
3. Mac receives notification, fetches reply
4. Mac sends reply text to terminal
5. Mac marks record as processed

## Requirements

- iOS 17.0+
- Same iCloud account as Mac
- CloudKit container: `iCloud.com.buzzbox.claudehub`
