import Foundation
import AppKit
import Combine
import WidgetKit
import UserNotifications

/// Central timer manager that handles all Pomodoro timer logic.
/// Published properties drive the SwiftUI views, and state changes
/// are broadcast to WebSocket clients and shared with the widget.
class PomodoroTimerManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    // MARK: - Published State

    @Published var state: TimerState
    @Published var configuration: TimerConfiguration {
        didSet {
            saveConfiguration()
            if state.phase == .idle {
                state.remainingSeconds = configuration.workDuration
                state.totalSeconds = configuration.workDuration
                state.pomodorosUntilLongBreak = configuration.pomodorosUntilLongBreak
            }
        }
    }
    @Published var dailyCompletedPomodoros: Int = 0
    @Published var taskTitle: String = "" {
        didSet {
            UserDefaults.standard.set(taskTitle, forKey: "pomodoroTaskTitle")
            broadcastState()
        }
    }

    // MARK: - Private

    private var timer: Timer?
    private var webSocketServer: WebSocketServer?
    private var httpServer: HTTPServer?
    private var tickSound: Bool = true
    private let overlayController = PhaseOverlayController()
    private var pendingAutoStart = false

    // MARK: - Init

    override init() {
        self.configuration = Self.loadConfiguration()
        self.state = TimerState(
            phase: .idle,
            remainingSeconds: Self.loadConfiguration().workDuration,
            totalSeconds: Self.loadConfiguration().workDuration,
            isRunning: false,
            completedPomodoros: 0,
            pomodorosUntilLongBreak: Self.loadConfiguration().pomodorosUntilLongBreak
        )
        super.init()
        self.taskTitle = UserDefaults.standard.string(forKey: "pomodoroTaskTitle") ?? ""
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        startServers()
    }

    // Show notification banners even when app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Timer Controls

    func start() {
        if state.phase == .idle {
            state.phase = .work
            state.remainingSeconds = configuration.workDuration
            state.totalSeconds = configuration.workDuration
        }
        state.isRunning = true
        scheduleTimer()
        broadcastState()
        saveSharedState()
    }

    func pause() {
        state.isRunning = false
        timer?.invalidate()
        timer = nil
        broadcastState()
        saveSharedState()
    }

    func toggleStartPause() {
        if state.isRunning {
            pause()
        } else {
            start()
        }
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        state = TimerState(
            phase: .idle,
            remainingSeconds: configuration.workDuration,
            totalSeconds: configuration.workDuration,
            isRunning: false,
            completedPomodoros: 0,
            pomodorosUntilLongBreak: configuration.pomodorosUntilLongBreak
        )
        broadcastState()
        saveSharedState()
    }

    func skip() {
        timer?.invalidate()
        timer = nil
        moveToNextPhase()
    }

    // MARK: - Timer Logic

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        if state.remainingSeconds > 0 {
            state.remainingSeconds -= 1
            broadcastState()
            saveSharedState()
        } else {
            phaseCompleted()
        }
    }

    private func phaseCompleted() {
        timer?.invalidate()
        timer = nil
        let completedPhase = state.phase
        let count = state.completedPomodoros + (completedPhase == .work ? 1 : 0)
        let willShowOverlay = configuration.showFullScreenAlert
        playCompletionAlert()
        sendPhaseCompletionNotification()
        showFullScreenOverlay(completedPhase: completedPhase, completedPomodoros: count)

        // Log completed work sessions to calendar
        if completedPhase == .work && configuration.addToCalendar {
            CalendarManager.shared.logSession(
                taskTitle: taskTitle.isEmpty ? nil : taskTitle,
                duration: configuration.workDuration,
                sessionNumber: count
            )
        }

        moveToNextPhase(deferAutoStart: willShowOverlay)
    }

    private func moveToNextPhase(deferAutoStart: Bool = false) {
        switch state.phase {
        case .work:
            state.completedPomodoros += 1
            dailyCompletedPomodoros += 1
            if state.completedPomodoros % configuration.pomodorosUntilLongBreak == 0 {
                state.phase = .longBreak
                state.remainingSeconds = configuration.longBreakDuration
                state.totalSeconds = configuration.longBreakDuration
            } else {
                state.phase = .shortBreak
                state.remainingSeconds = configuration.shortBreakDuration
                state.totalSeconds = configuration.shortBreakDuration
            }
            if deferAutoStart {
                // Will start when overlay is dismissed
                pendingAutoStart = true
                state.isRunning = false
            } else if configuration.autoStartBreaks {
                state.isRunning = true
                scheduleTimer()
            } else {
                state.isRunning = false
            }

        case .shortBreak, .longBreak:
            state.phase = .work
            state.remainingSeconds = configuration.workDuration
            state.totalSeconds = configuration.workDuration
            if deferAutoStart {
                pendingAutoStart = true
                state.isRunning = false
            } else if configuration.autoStartPomodoros {
                state.isRunning = true
                scheduleTimer()
            } else {
                state.isRunning = false
            }

        case .idle:
            state.phase = .work
            state.remainingSeconds = configuration.workDuration
            state.totalSeconds = configuration.workDuration
            state.isRunning = false
        }

        broadcastState()
        saveSharedState()
        reloadWidget()
    }

    // MARK: - Notifications & Alerts

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Play a system sound and bounce the dock icon so the user notices
    private func playCompletionAlert() {
        // Play system sound
        if configuration.playSoundAlert {
            if let sound = NSSound(named: NSSound.Name("Glass")) {
                sound.play()
            } else {
                NSSound.beep()
            }
        }

        // Bounce dock icon to grab attention
        NSApp.requestUserAttention(.criticalRequest)
    }

    /// Show a full-screen overlay that must be dismissed
    private func showFullScreenOverlay(completedPhase: TimerPhase, completedPomodoros: Int) {
        guard configuration.showFullScreenAlert else { return }
        overlayController.onDismiss = { [weak self] in
            guard let self, self.pendingAutoStart else { return }
            self.pendingAutoStart = false
            self.start()
        }
        overlayController.show(completedPhase: completedPhase, completedPomodoros: completedPomodoros)
    }

    private func sendPhaseCompletionNotification() {
        guard configuration.showNotificationAlert else { return }
        let content = UNMutableNotificationContent()

        switch state.phase {
        case .work:
            content.title = "Focus session complete! 🎉"
            content.body = "Great work! Time for a break."
            content.sound = .default
        case .shortBreak, .longBreak:
            content.title = "Break is over! 🍅"
            content.body = "Ready to focus again?"
            content.sound = .default
        case .idle:
            return
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Server Management

    private func startServers() {
        // Start WebSocket server
        webSocketServer = WebSocketServer()
        webSocketServer?.onMessageReceived = { [weak self] message in
            self?.handleWebSocketMessage(message)
        }
        webSocketServer?.start(port: AppConstants.webSocketPort)

        // Find web directory - try multiple locations
        let webDir = findWebDirectory()
        if let webDir {
            httpServer = HTTPServer(webDirectory: webDir, webSocketPort: AppConstants.webSocketPort)
            httpServer?.onWebSocketMessage = { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            httpServer?.start(port: AppConstants.httpPort)
            print("📂 Serving web files from: \(webDir.path)")
        } else {
            print("⚠️ Web directory not found — HTTP server not started")
        }

        print("🍅 Pomodoro servers started")
        print("   Web UI: http://localhost:\(AppConstants.httpPort)")
        print("   WebSocket: ws://localhost:\(AppConstants.webSocketPort)")
    }

    private func findWebDirectory() -> URL? {
        // 1. Check for "Web" folder in bundle resources (folder reference)
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Web"),
           FileManager.default.fileExists(atPath: url.appendingPathComponent("index.html").path) {
            return url
        }

        // 2. Check for "Web" folder directly in bundle resources (copied files)
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            return url.deletingLastPathComponent()
        }

        // 3. Check bundle resources root (files may be copied flat)
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            return url.deletingLastPathComponent()
        }

        // 4. Fallback: source directory for development
        let sourceDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Core/
            .deletingLastPathComponent() // Pomodoro/
            .appendingPathComponent("Resources/Web")
        if FileManager.default.fileExists(atPath: sourceDir.appendingPathComponent("index.html").path) {
            return sourceDir
        }

        return nil
    }

    func handleWebSocketMessage(_ message: String) {
        print("🌐 Raw WS message: \(message)")
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else {
            print("⚠️ Failed to parse WS message")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            print("🌐 WS action: \(action)")
            switch action {
            case "start":
                self.start()
            case "pause":
                self.pause()
            case "toggle":
                self.toggleStartPause()
            case "reset":
                print("🚨 RESET triggered via WebSocket!")
                self.reset()
            case "skip":
                self.skip()
            case "getState":
                self.broadcastState()
            case "updateSettings":
                print("⚙️ updateSettings received via WebSocket")
                if let settingsJson = json["settings"] as? [String: Any],
                   let settingsData = try? JSONSerialization.data(withJSONObject: settingsJson),
                   let settingsString = String(data: settingsData, encoding: .utf8),
                   let newConfig = TimerConfiguration.fromJSON(settingsString) {
                    self.configuration = newConfig
                    self.broadcastState()
                }
            case "updateTask":
                if let title = json["title"] as? String {
                    self.taskTitle = title
                }
            default:
                print("⚠️ Unknown WS action: \(action)")
                break
            }
        }
    }

    func broadcastState() {
        let escapedTitle = taskTitle
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let stateMessage = """
        {"type":"state","state":\(state.jsonString),"config":\(configuration.jsonString),"daily_completed":\(dailyCompletedPomodoros),"task_title":"\(escapedTitle)"}
        """
        webSocketServer?.broadcast(stateMessage)
        httpServer?.broadcastWebSocket(stateMessage)
    }

    func openWebUI() {
        let url = URL(string: "http://localhost:\(AppConstants.httpPort)")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Persistence

    private func saveSharedState() {
        UserDefaults.shared.set(state.jsonString, forKey: AppConstants.timerStateKey)
        UserDefaults.shared.set(Date().timeIntervalSince1970, forKey: AppConstants.lastUpdateKey)
    }

    private func saveConfiguration() {
        UserDefaults.shared.set(configuration.jsonString, forKey: AppConstants.timerConfigKey)
        UserDefaults.standard.set(configuration.jsonString, forKey: AppConstants.timerConfigKey)
    }

    private static func loadConfiguration() -> TimerConfiguration {
        if let json = UserDefaults.standard.string(forKey: AppConstants.timerConfigKey),
           let config = TimerConfiguration.fromJSON(json) {
            return config
        }
        return .default
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
    }
}
