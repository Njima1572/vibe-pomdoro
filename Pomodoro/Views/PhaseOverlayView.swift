import SwiftUI
import AppKit

// MARK: - Overlay Window Controller

/// Manages a full-screen translucent overlay that appears when a timer phase completes.
/// The user must dismiss it, making it impossible to miss.
class PhaseOverlayController {
    private var window: NSWindow?
    private var monitor: Any?
    private var isDismissing = false

    func show(completedPhase: TimerPhase, completedPomodoros: Int) {
        // Dismiss any existing overlay
        dismiss()

        guard let screen = NSScreen.main else { return }

        isDismissing = false

        // Create a borderless, full-screen window above everything
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar + 1
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        let overlayView = PhaseOverlayView(
            completedPhase: completedPhase,
            completedPomodoros: completedPomodoros,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        window.contentView = NSHostingView(rootView: overlayView)

        self.window = window

        // Also allow dismiss with Escape or Space
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 || event.keyCode == 49 { // Escape or Space
                self?.dismiss()
                return nil
            }
            return event
        }

        window.makeKeyAndOrderFront(nil)

        // Activate the app so the overlay is interactable
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true

        // Remove event monitor FIRST to prevent callbacks during teardown
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil

        // Clear content view before closing to release SwiftUI hosting view cleanly
        window?.contentView = nil
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - Overlay SwiftUI View

struct PhaseOverlayView: View {
    let completedPhase: TimerPhase
    let completedPomodoros: Int
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Blurred translucent background
            Color.black.opacity(appeared ? 0.65 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.4), value: appeared)

            VStack(spacing: 24) {
                // Phase icon
                Text(icon)
                    .font(.system(size: 80))
                    .scaleEffect(appeared ? 1.0 : 0.3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)

                // Title
                Text(title)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)

                // Subtitle
                Text(subtitle)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                    .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)

                // Session count (only after work)
                if completedPhase == .work {
                    HStack(spacing: 8) {
                        ForEach(0..<completedPomodoros, id: \.self) { _ in
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                                .font(.title2)
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)
                }

                Spacer().frame(height: 20)

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(accentColor.gradient)
                                .shadow(color: accentColor.opacity(0.5), radius: 16, y: 8)
                        )
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1.0 : 0.8)
                .animation(.easeOut(duration: 0.5).delay(0.45), value: appeared)

                // Hint
                Text("Press Space or Esc to dismiss")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: appeared)
            }
            .padding(40)
        }
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
    }

    // MARK: - Content

    private var icon: String {
        switch completedPhase {
        case .work: return "🎉"
        case .shortBreak: return "🍅"
        case .longBreak: return "🍅"
        case .idle: return "🍅"
        }
    }

    private var title: String {
        switch completedPhase {
        case .work: return "Focus Complete!"
        case .shortBreak: return "Break's Over!"
        case .longBreak: return "Long Break Done!"
        case .idle: return "Ready"
        }
    }

    private var subtitle: String {
        switch completedPhase {
        case .work:
            return "Great work! You've earned a break.\nSession \(completedPomodoros) complete."
        case .shortBreak:
            return "Feeling refreshed?\nTime to get back to work."
        case .longBreak:
            return "Well rested!\nLet's start a new cycle."
        case .idle:
            return ""
        }
    }

    private var accentColor: Color {
        switch completedPhase {
        case .work: return .green
        case .shortBreak, .longBreak: return .red
        case .idle: return .gray
        }
    }
}
