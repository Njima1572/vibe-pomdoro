import Foundation
import Network

/// Lightweight HTTP server using Network.framework to serve the web UI files.
/// Handles basic GET requests for static files (HTML, CSS, JS, images).
class HTTPServer {

    // MARK: - Properties

    private var listener: NWListener?
    private let webDirectory: URL
    private let webSocketPort: UInt16
    private let queue = DispatchQueue(label: "com.kochi.pomodoro.http", qos: .userInitiated)

    // MARK: - Init

    init(webDirectory: URL, webSocketPort: UInt16) {
        self.webDirectory = webDirectory
        self.webSocketPort = webSocketPort
    }

    // MARK: - Server Lifecycle

    func start(port: UInt16) {
        let parameters = NWParameters.tcp

        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("❌ HTTP server failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ HTTP server listening on port \(port)")
            case .failed(let error):
                print("❌ HTTP server failed: \(error)")
            case .cancelled:
                print("⚠️ HTTP server cancelled")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }

            let request = String(data: data, encoding: .utf8) ?? ""
            let response = self.handleRequest(request)

            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    // MARK: - Request Processing

    private func handleRequest(_ request: String) -> Data {
        let lines = request.split(separator: "\r\n")
        guard let firstLine = lines.first else {
            return buildResponse(status: 400, body: "Bad Request".data(using: .utf8)!, contentType: "text/plain")
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2,
              String(parts[0]) == "GET" else {
            return buildResponse(status: 405, body: "Method Not Allowed".data(using: .utf8)!, contentType: "text/plain")
        }

        var path = String(parts[1])

        // Default to index.html
        if path == "/" { path = "/index.html" }

        // Security: prevent directory traversal
        let cleanPath = path.replacingOccurrences(of: "..", with: "")

        // Serve the file
        let filePath = webDirectory.appendingPathComponent(cleanPath)

        guard FileManager.default.fileExists(atPath: filePath.path),
              let fileData = try? Data(contentsOf: filePath) else {
            let notFound = "404 Not Found".data(using: .utf8)!
            return buildResponse(status: 404, body: notFound, contentType: "text/plain")
        }

        var body = fileData

        // Inject WebSocket port into HTML
        if cleanPath.hasSuffix(".html") {
            if var htmlString = String(data: fileData, encoding: .utf8) {
                htmlString = htmlString.replacingOccurrences(
                    of: "{{WS_PORT}}",
                    with: String(webSocketPort)
                )
                body = htmlString.data(using: .utf8) ?? fileData
            }
        }

        let contentType = mimeType(for: cleanPath)
        return buildResponse(status: 200, body: body, contentType: contentType)
    }

    // MARK: - HTTP Response Builder

    private func buildResponse(status: Int, body: Data, contentType: String) -> Data {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Unknown"
        }

        let headers = [
            "HTTP/1.1 \(status) \(statusText)",
            "Content-Type: \(contentType); charset=utf-8",
            "Content-Length: \(body.count)",
            "Access-Control-Allow-Origin: *",
            "Cache-Control: no-cache",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        var response = headers.data(using: .utf8) ?? Data()
        response.append(body)
        return response
    }

    // MARK: - MIME Types

    private func mimeType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "html": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        default: return "application/octet-stream"
        }
    }
}
