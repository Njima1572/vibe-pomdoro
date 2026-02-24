import Foundation
import Network
import CryptoKit

/// Lightweight HTTP server using Network.framework to serve the web UI files.
/// Also handles WebSocket upgrades on the same port so everything works through a single tunnel.
class HTTPServer {

    // MARK: - Properties

    private var listener: NWListener?
    private let webDirectory: URL
    private let webSocketPort: UInt16
    private let queue = DispatchQueue(label: "com.kochi.pomodoro.http", qos: .userInitiated)

    /// Called when a WebSocket message is received from a client on this port.
    var onWebSocketMessage: ((String) -> Void)?

    /// Active WebSocket connections (upgraded from HTTP).
    private var wsConnections: [Int: NWConnection] = [:]
    private var nextWsId = 0

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
        wsConnections.values.forEach { $0.cancel() }
        wsConnections.removeAll()
    }

    /// Broadcast a message to all WebSocket connections on this port.
    func broadcastWebSocket(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        let frame = buildWebSocketFrame(payload: data, opcode: 0x01) // text frame

        for (id, connection) in wsConnections {
            connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                if error != nil {
                    self?.wsConnections.removeValue(forKey: id)
                }
            })
        }
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
            let headers = self.parseHeaders(request)

            // Check for WebSocket upgrade
            if headers["upgrade"]?.lowercased() == "websocket",
               let key = headers["sec-websocket-key"] {
                self.handleWebSocketUpgrade(connection: connection, key: key)
                return
            }

            // Regular HTTP request
            let response = self.handleRequest(request)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    // MARK: - HTTP Headers Parser

    private func parseHeaders(_ request: String) -> [String: String] {
        var headers: [String: String] = [:]
        let lines = request.components(separatedBy: "\r\n")
        for line in lines.dropFirst() { // Skip request line
            if line.isEmpty { break }
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        return headers
    }

    // MARK: - WebSocket Upgrade

    private func handleWebSocketUpgrade(connection: NWConnection, key: String) {
        // Compute Sec-WebSocket-Accept
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = key + magic
        let hash = Insecure.SHA1.hash(data: Data(combined.utf8))
        let accept = Data(hash).base64EncodedString()

        let response = [
            "HTTP/1.1 101 Switching Protocols",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Accept: \(accept)",
            "",
            ""
        ].joined(separator: "\r\n")

        let connId = nextWsId
        nextWsId += 1

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil else {
                connection.cancel()
                return
            }

            self?.wsConnections[connId] = connection
            print("🔌 HTTP-WS client \(connId) upgraded to WebSocket")

            // Send getState to sync
            self?.onWebSocketMessage?("{\"action\":\"getState\"}")

            // Start receiving WebSocket frames
            self?.receiveWebSocketFrames(connection: connection, connId: connId, buffer: Data())
        })

        // Handle disconnection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.wsConnections.removeValue(forKey: connId)
                print("🔌 HTTP-WS client \(connId) disconnected")
            default:
                break
            }
        }
    }

    // MARK: - WebSocket Frame Handling

    private func receiveWebSocketFrames(connection: NWConnection, connId: Int, buffer: Data) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error = error {
                print("❌ HTTP-WS \(connId) receive error: \(error)")
                self.wsConnections.removeValue(forKey: connId)
                return
            }

            guard let data = data, !data.isEmpty else {
                if isComplete {
                    self.wsConnections.removeValue(forKey: connId)
                    connection.cancel()
                }
                return
            }

            var buf = buffer + data

            // Parse as many complete frames as possible
            while let (message, opcode, consumed) = self.parseWebSocketFrame(buf) {
                buf = Data(buf.dropFirst(consumed))

                switch opcode {
                case 0x01: // Text frame
                    if let text = message {
                        self.onWebSocketMessage?(text)
                    }
                case 0x08: // Close
                    // Send close frame back
                    let closeFrame = self.buildWebSocketFrame(payload: Data(), opcode: 0x08)
                    connection.send(content: closeFrame, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                    self.wsConnections.removeValue(forKey: connId)
                    return
                case 0x09: // Ping → reply with Pong
                    let pong = self.buildWebSocketFrame(payload: message?.data(using: .utf8) ?? Data(), opcode: 0x0A)
                    connection.send(content: pong, completion: .contentProcessed { _ in })
                default:
                    break
                }
            }

            // Continue receiving
            if connection.state == .ready {
                self.receiveWebSocketFrames(connection: connection, connId: connId, buffer: buf)
            }
        }
    }

    /// Parse a single WebSocket frame. Returns (message, opcode, bytesConsumed) or nil if incomplete.
    private func parseWebSocketFrame(_ data: Data) -> (String?, UInt8, Int)? {
        guard data.count >= 2 else { return nil }

        let byte0 = data[data.startIndex]
        let byte1 = data[data.startIndex + 1]

        let opcode = byte0 & 0x0F
        let isMasked = (byte1 & 0x80) != 0
        var payloadLength = UInt64(byte1 & 0x7F)
        var offset = 2

        if payloadLength == 126 {
            guard data.count >= offset + 2 else { return nil }
            payloadLength = UInt64(data[data.startIndex + offset]) << 8 |
                           UInt64(data[data.startIndex + offset + 1])
            offset += 2
        } else if payloadLength == 127 {
            guard data.count >= offset + 8 else { return nil }
            payloadLength = 0
            for i in 0..<8 {
                payloadLength = payloadLength << 8 | UInt64(data[data.startIndex + offset + i])
            }
            offset += 8
        }

        var mask: [UInt8] = []
        if isMasked {
            guard data.count >= offset + 4 else { return nil }
            mask = Array(data[(data.startIndex + offset)..<(data.startIndex + offset + 4)])
            offset += 4
        }

        let totalFrameSize = offset + Int(payloadLength)
        guard data.count >= totalFrameSize else { return nil }

        var payload = Array(data[(data.startIndex + offset)..<(data.startIndex + totalFrameSize)])

        // Unmask
        if isMasked {
            for i in 0..<payload.count {
                payload[i] ^= mask[i % 4]
            }
        }

        let message = String(bytes: payload, encoding: .utf8)
        return (message, opcode, totalFrameSize)
    }

    /// Build a WebSocket frame (server-to-client, no masking).
    private func buildWebSocketFrame(payload: Data, opcode: UInt8) -> Data {
        var frame = Data()

        // FIN + opcode
        frame.append(0x80 | opcode)

        if payload.count < 126 {
            frame.append(UInt8(payload.count))
        } else if payload.count < 65536 {
            frame.append(126)
            frame.append(UInt8((payload.count >> 8) & 0xFF))
            frame.append(UInt8(payload.count & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((payload.count >> (i * 8)) & 0xFF))
            }
        }

        frame.append(payload)
        return frame
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

        // Inject WebSocket port into HTML and JS files
        if cleanPath.hasSuffix(".html") || cleanPath.hasSuffix(".js") {
            if var text = String(data: fileData, encoding: .utf8) {
                text = text.replacingOccurrences(
                    of: "{{WS_PORT}}",
                    with: String(webSocketPort)
                )
                body = text.data(using: .utf8) ?? fileData
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
