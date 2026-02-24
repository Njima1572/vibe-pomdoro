# 🍅 Pomodoro Timer

A beautiful, native macOS Pomodoro timer that lives in your menu bar — with a synchronized web dashboard accessible from any device.

## ✨ Features

### Core Timer

- **Menu Bar Timer** — Always-visible timer in your macOS menu bar with phase-colored icon and countdown
- **macOS Widget** — WidgetKit-powered desktop widget (small & medium sizes)
- **Full-Screen Phase Overlay** — Immersive overlay when phases complete
- **Notifications** — Native macOS notifications and sound alerts
- **Global Keyboard Shortcuts** — `⌃⌥Space` (toggle), `⌃⌥R` (reset), `⌃⌥S` (skip) — configurable

### Cross-Device Sync

- **Web Dashboard** — Beautiful dark-themed web UI, syncs in real-time via WebSocket
- **QR Code Sharing** — Scan from Settings → Sync to instantly open the dashboard on your phone
- **LAN Access** — Any device on the same WiFi can connect (no account needed)
- **Cloudflare Tunnel** — One-click HTTPS tunnel for access from anywhere (`brew install cloudflared`)
- **Synced Task Title** — "What are you working on?" syncs across all devices in real-time

### Mobile-Friendly Web UI

- **Responsive Design** — Optimized for phones, tablets, and desktops
- **Keep Screen Awake** — Toggle to prevent your phone's screen from sleeping (video-based fallback for HTTP)
- **Browser Notifications** — Phase completion alerts with vibration on mobile
- **Audio Alerts** — Web Audio API beep on phase transitions
- **Live Tab Title** — Browser tab shows `23:45 — Task Name`

## Architecture

```
┌──────────────────────────────────────────────────┐
│             SwiftUI Mac Menu Bar App             │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Menu Bar │  │  Widget  │  │  HTTP Server  │  │
│  │  Timer   │  │(WidgetKit)│  │  (port 8094)  │  │
│  └──────────┘  └──────────┘  │  + WebSocket  │  │
│                               └───────┬───────┘  │
│       PomodoroTimerManager            │          │
│  ┌──────────┐  ┌──────────────────┐   │          │
│  │ Floating │  │  WebSocket Srv   │   │          │
│  │  Panel   │  │   (port 8095)    │   │          │
│  └──────────┘  └────────┬─────────┘   │          │
│                          │             │          │
│      ┌── Cloudflare Tunnel (optional) ─┘          │
│      │   (cloudflared → trycloudflare.com)        │
└──────┼───────────────────┬────────────────────────┘
       │                   │
       │    ws(s)://        │    http(s)://
       ▼                   ▼
  ┌─────────────────────────────────┐
  │        Web Dashboard            │
  │   (HTML / CSS / Vanilla JS)     │
  │                                 │
  │  📱 Phone  💻 Laptop  🖥 Desktop │
  └─────────────────────────────────┘
```

**Two WebSocket paths:**

- **Port 8095** — Dedicated WebSocket server (local/LAN direct connections)
- **Port 8094** — HTTP server with WebSocket upgrade support (used by Cloudflare tunnel, which can only proxy one port)

## Tech Stack

- **Swift / SwiftUI** — Native macOS app with `MenuBarExtra`
- **WidgetKit** — Desktop widgets via App Groups shared state
- **Network.framework** — Zero-dependency HTTP + WebSocket servers (no SwiftNIO)
- **CryptoKit** — SHA-1 for WebSocket handshake (`Insecure.SHA1`)
- **CoreImage** — QR code generation (`CIQRCodeGenerator`)
- **Vanilla HTML/CSS/JS** — Lightweight, beautiful web dashboard with glassmorphism design
- **cloudflared** — Optional Cloudflare quick tunnel for HTTPS access

## Requirements

- macOS 14.0+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) (optional, `brew install cloudflared`)

## Building

```bash
# Install dependencies
brew install xcodegen

# Build (generates Xcode project + builds)
./build.sh build

# Build and run
./build.sh run

# Clean build
./build.sh clean

# Or open in Xcode
./build.sh build && open Pomodoro.xcodeproj
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
| Sound Alerts | ✅ |
| Notification Alerts | ✅ |
| Full-Screen Alerts | ✅ |
| Global Shortcuts | ✅ |

## Cross-Device Sync

### LAN (Same WiFi)

1. Open the app → Settings → **Sync** tab
2. Scan the QR code with your phone, or type the URL
3. Timer syncs in real-time — no account needed

### Cloudflare Tunnel (Anywhere)

1. Install: `brew install cloudflared`
2. Click the menu bar icon → **Share via Tunnel**
3. A temporary HTTPS URL is generated (e.g., `https://random-words.trycloudflare.com`)
4. Share the URL — works from anywhere, with full HTTPS support

## Project Structure

```
├── Pomodoro/                    # Main app target
│   ├── PomodoroApp.swift        # App entry + MenuBarExtra + Tunnel
│   ├── Views/
│   │   ├── MenuBarView.swift    # Menu bar popup UI
│   │   ├── SettingsView.swift   # Settings window (Timer, Sync, About)
│   │   ├── FloatingTimerPanel.swift
│   │   └── PhaseOverlayView.swift
│   ├── Core/
│   │   ├── PomodoroTimer.swift  # Central timer logic + message handling
│   │   ├── HotkeyManager.swift  # Global keyboard shortcuts
│   │   ├── NetworkUtils.swift   # LAN IP detection + QR code generation
│   │   └── TunnelManager.swift  # Cloudflare tunnel lifecycle
│   ├── Server/
│   │   ├── HTTPServer.swift     # Static file server + WebSocket upgrade
│   │   └── WebSocketServer.swift # Dedicated WebSocket server
│   └── Resources/
│       ├── Assets.xcassets      # App icon
│       └── Web/                 # Web dashboard
│           ├── index.html
│           ├── style.css
│           └── app.js
├── PomodoroWidget/              # WidgetKit extension
├── Shared/
│   ├── SharedTimerState.swift   # TimerState + TimerConfiguration
│   └── Constants.swift          # Ports, keys, identifiers
├── build.sh                     # Build script
├── project.yml                  # XcodeGen project spec
└── icon_source.svg              # App icon source
```

## License

MIT
