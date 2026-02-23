import SwiftUI
import AppKit

/// A Spotlight-style floating timer panel that can be toggled with a global hotkey.
class FloatingTimerPanel {
    private var panel: NSPanel?
    private var timerManager: PomodoroTimerManager?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func toggle(timerManager: PomodoroTimerManager) {
        self.timerManager = timerManager
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show(timerManager: timerManager)
        }
    }

    func show(timerManager: PomodoroTimerManager) {
        self.timerManager = timerManager

        if let panel = panel {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            animateIn()
            return
        }

        let contentView = FloatingTimerView(
            timerManager: timerManager,
            onDismiss: { [weak self] in self?.hide() }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        // Use visual effect for native blur
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = visualEffect.bounds
        hostingView.autoresizingMask = [.width, .height]

        // Layer the hosting view on top of the blur
        visualEffect.addSubview(hostingView)
        panel.contentView = visualEffect

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 160
            let y = screenFrame.midY + 50
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = panel

        // Start hidden for animation
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        animateIn()
    }

    func hide() {
        guard let panel = panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func animateIn() {
        guard let panel = panel else { return }
        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }
}

// MARK: - Floating Timer View

struct FloatingTimerView: View {
    @ObservedObject var timerManager: PomodoroTimerManager
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Phase + status
            HStack {
                Text(timerManager.state.phase.emoji)
                    .font(.title2)
                Text(timerManager.state.phase.displayName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(phaseColor)

                Spacer()

                if timerManager.state.phase != .idle {
                    Text(timerManager.state.isRunning ? "RUNNING" : "PAUSED")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(timerManager.state.isRunning ? Color.green : Color.orange)
                        )
                }
            }

            // Timer display
            Text(timerManager.state.formattedTime)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.primary)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(phaseColor.gradient)
                        .frame(width: geo.size.width * timerManager.state.progress)
                        .animation(.easeInOut(duration: 0.3), value: timerManager.state.progress)
                }
            }
            .frame(height: 6)

            // Controls
            HStack(spacing: 16) {
                Button { timerManager.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(timerManager.state.phase == .idle)

                Button { timerManager.toggleStartPause() } label: {
                    Image(systemName: timerManager.state.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(phaseColor.gradient)
                                .shadow(color: phaseColor.opacity(0.4), radius: 6, y: 3)
                        )
                }
                .buttonStyle(.plain)

                Button { timerManager.skip() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(timerManager.state.phase == .idle)

                Spacer()

                // Shortcut hint
                Text("⌃⌥P")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                    )
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private var phaseColor: Color {
        switch timerManager.state.phase {
        case .idle: return .gray
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}
