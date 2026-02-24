import Foundation
import Combine

/// Manages a Cloudflare quick tunnel to expose the local HTTP server over HTTPS.
/// Uses `cloudflared tunnel --url http://localhost:<port>` which requires no account.
class TunnelManager: ObservableObject {

    // MARK: - Published State

    @Published var tunnelURL: String?
    @Published var isRunning = false
    @Published var error: String?

    // MARK: - Private

    private var process: Process?
    private var outputPipe: Pipe?

    // MARK: - Lifecycle

    func start(localPort: UInt16) {
        guard !isRunning else { return }

        // Find cloudflared
        let cloudflaredPath = findCloudflared()
        guard let path = cloudflaredPath else {
            error = "cloudflared not found. Install with: brew install cloudflared"
            print("❌ cloudflared not found")
            return
        }

        error = nil
        tunnelURL = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["tunnel", "--url", "http://localhost:\(localPort)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe // cloudflared outputs the URL to stderr

        self.process = process
        self.outputPipe = pipe

        // Read output to capture the tunnel URL
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }

            // cloudflared prints something like:
            // +-------------------------------------------+
            // |  Your quick Tunnel has been created! ...   |
            // |  https://random-words.trycloudflare.com    |
            // +-------------------------------------------+
            if let range = output.range(of: "https://[a-zA-Z0-9\\-]+\\.trycloudflare\\.com", options: .regularExpression) {
                let url = String(output[range])
                DispatchQueue.main.async {
                    self?.tunnelURL = url
                    self?.isRunning = true
                    print("🌐 Tunnel active: \(url)")
                }
            }

            // Also print for debugging
            for line in output.components(separatedBy: "\n") where !line.isEmpty {
                print("☁️ cloudflared: \(line)")
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.tunnelURL = nil
                print("☁️ Tunnel stopped")
            }
        }

        do {
            try process.run()
            isRunning = true
            print("☁️ Starting cloudflared tunnel for port \(localPort)...")
        } catch {
            self.error = "Failed to start tunnel: \(error.localizedDescription)"
            self.isRunning = false
            print("❌ Failed to start cloudflared: \(error)")
        }
    }

    func stop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        isRunning = false
        tunnelURL = nil
    }

    deinit {
        stop()
    }

    // MARK: - Helpers

    /// The full tunnel dashboard URL, or falls back to LAN.
    var dashboardURL: String {
        tunnelURL ?? NetworkUtils.dashboardURL
    }

    static var isCloudflaredInstalled: Bool {
        findCloudflaredStatic() != nil
    }

    private func findCloudflared() -> String? {
        Self.findCloudflaredStatic()
    }

    private static func findCloudflaredStatic() -> String? {
        let paths = [
            "/opt/homebrew/bin/cloudflared",
            "/usr/local/bin/cloudflared",
            "/usr/bin/cloudflared"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}
