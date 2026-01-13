# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## About ClaudeHub

A native macOS app for managing Claude Code sessions across projects. Built with SwiftUI and SwiftTerm.

**Owner:** Baron Miller (personal project under Buzzbox)

## Team

This project uses the Buzzbox team defined in `~/Dropbox/Buzzbox/CLAUDE.md`. Key roles:

| Role | Who | Focus |
|------|-----|-------|
| **CTO** | Reid | Swift/SwiftUI code, architecture, debugging |
| **QA** | Quinn | Test before shipping, verify fixes |
| **UX** | Maya | App layout, user flows, macOS conventions |

## Tech Stack

- **SwiftUI** - Native macOS UI
- **SwiftTerm** - Terminal emulation ([github.com/migueldeicaza/SwiftTerm](https://github.com/migueldeicaza/SwiftTerm))
- **Swift Package Manager** - No Xcode project needed

## Build & Run

```bash
cd ~/code/claudehub
swift build
.build/debug/ClaudeHub
```

Or rebuild and run:
```bash
cd ~/code/claudehub && swift build && .build/debug/ClaudeHub
```

## Project Structure

```
claudehub/
├── Package.swift           # Swift package manifest
├── CLAUDE.md              # This file
├── README.md              # Project overview
├── MONDAY-NIGHT.md        # Session notes
└── ClaudeHub/
    ├── ClaudeHubApp.swift # Main app + AppState + persistence
    ├── Models/
    │   ├── Project.swift
    │   └── Session.swift
    └── Views/
        ├── LauncherView.swift    # Home screen with project cards
        ├── WorkspaceView.swift   # Split view: sidebar + terminal
        ├── TerminalView.swift    # SwiftTerm integration
        ├── MenuBarView.swift     # Menu bar dropdown
        └── SettingsView.swift    # Add/remove projects
```

## Features

### Completed
- Glass design launcher with project cards
- Two sections: Main Projects + Clients
- Workspace view with session sidebar
- SwiftTerm terminal emulation
- Auto-start Claude when clicking a project
- Settings panel for managing projects
- Session persistence (survives restart)
- Session delete/rename
- Menu bar icon
- Keyboard focus improvements
- App delegate for proper window activation

### Needs Testing
- Keyboard input in terminal
- Claude process startup and response

## Git

**Repo:** github.com/buzzboxmedia/claudehub (public)

```bash
git add -A && git commit -m "message" && git push
```

## Session Notes

See `MONDAY-NIGHT.md` for detailed notes from the initial build session.
