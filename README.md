# 🍅 Pomodoro Timer

A beautiful, native macOS Pomodoro timer that lives in your menu bar — with a synchronized web dashboard.

## Features

- **Menu Bar Timer** — Always-visible timer in your macOS menu bar with dynamic icon and remaining time
- **macOS Widget** — WidgetKit-powered desktop widget (small & medium sizes)
- **Web Dashboard** — Real-time synchronized web UI accessible at `http://localhost:8094`
- **Auto Phase Transitions** — Configurable auto-start for breaks and focus sessions
- **Notifications** — Native macOS notifications when phases complete
- **Keyboard Shortcuts** — Space (play/pause), R (reset), S (skip) in the web UI

## Architecture

```
┌─────────────────────────────────────────────┐
│           SwiftUI Mac Menu Bar App          │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐ │
│  │ Menu Bar │  │  Widget  │  │ HTTP +    │ │
│  │  Timer   │  │(WidgetKit)│  │ WebSocket │ │
│  └──────────┘  └──────────┘  └─────┬─────┘ │
│                Core Timer                    │
└──────────────────┬──────────────────────────┘
                   │ WebSocket (ws://localhost:8095)
         ┌─────────┴─────────┐
         │   Web Dashboard   │
         │  (HTML/CSS/JS)    │
         └───────────────────┘
```

## Tech Stack

- **Swift / SwiftUI** — Native macOS app with `MenuBarExtra`
- **WidgetKit** — Desktop widgets via App Groups shared state
- **Network.framework** — Zero-dependency HTTP + WebSocket servers
- **Vanilla HTML/CSS/JS** — Lightweight, beautiful web dashboard

## Requirements

- macOS 14.0+
- Xcode 15+

## Building

```bash
# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Build from command line
xcodebuild -project Pomodoro.xcodeproj -scheme Pomodoro build

# Or open in Xcode
open Pomodoro.xcodeproj
```

## Configuration

Default timer settings (configurable in Settings or via web dashboard):

| Setting | Default |
|---------|---------|
| Focus Duration | 25 min |
| Short Break | 5 min |
| Long Break | 15 min |
| Sessions until Long Break | 4 |
| Auto-start Breaks | ✅ |
| Auto-start Focus | ❌ |

## Web Dashboard

Once the app is running, open `http://localhost:8094` in any browser. The web UI syncs in real-time with the menu bar timer via WebSocket.

## Project Structure

```
├── Pomodoro/              # Main app target
│   ├── PomodoroApp.swift  # App entry point + MenuBarExtra
│   ├── Views/             # SwiftUI views
│   ├── Core/              # Timer logic
│   ├── Server/            # HTTP + WebSocket servers
│   └── Resources/
│       ├── Assets.xcassets
│       └── Web/           # Web dashboard files
├── PomodoroWidget/        # Widget extension
├── Shared/                # Shared models (App Group)
└── project.yml            # XcodeGen spec
```
