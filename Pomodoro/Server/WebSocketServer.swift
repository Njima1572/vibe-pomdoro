import Foundation
import Network

/// Lightweight WebSocket server using Network.framework.
/// Handles multiple concurrent client connections and broadcasts timer state updates.
class WebSocketServer {

    // MARK: - Properties

    private var listener: NWListener?
    private var connections: [Int: NWConnection] = [:]
    private var nextConnectionId = 0
    private let queue = DispatchQueue(label: "com.kochi.pomodoro.websocket", qos: .userInitiated)

    var onMessageReceived: ((String) -> Void)?

    // MARK: - Server Lifecycle

    func start(port: UInt16) {
        let parameters = NWParameters(tls: nil)

        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("❌ WebSocket server failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ WebSocket server listening on port \(port)")
            case .failed(let error):
                print("❌ WebSocket server failed: \(error)")
            case .cancelled:
                print("⚠️ WebSocket server cancelled")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        let connectionId = nextConnectionId
        nextConnectionId += 1
        connections[connectionId] = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("🔌 WebSocket client \(connectionId) connected")
                // Send current state to newly connected client
                self?.onMessageReceived?("{\"action\":\"getState\"}")
            case .failed(let error):
                print("❌ WebSocket client \(connectionId) failed: \(error)")
                self?.removeConnection(connectionId)
            case .cancelled:
                print("🔌 WebSocket client \(connectionId) disconnected")
                self?.removeConnection(connectionId)
            default:
                break
            }
        }

        connection.start(queue: queue)
        receiveMessage(from: connection, connectionId: connectionId)
    }

    private func removeConnection(_ connectionId: Int) {
        connections.removeValue(forKey: connectionId)
    }

    // MARK: - Message Handling

    private func receiveMessage(from connection: NWConnection, connectionId: Int) {
        connection.receiveMessage { [weak self] content, context, isComplete, error in
            if let error = error {
                print("❌ WebSocket receive error from client \(connectionId): \(error)")
                self?.removeConnection(connectionId)
                return
            }

            if let data = content, !data.isEmpty {
                // Check for WebSocket metadata
                if let context = context {
                    let isWebSocket = context.protocolMetadata.contains { metadata in
                        metadata is NWProtocolWebSocket.Metadata
                    }

                    if isWebSocket, let message = String(data: data, encoding: .utf8) {
                        self?.onMessageReceived?(message)
                    }
                }
            }

            // Continue receiving
            if connection.state == .ready {
                self?.receiveMessage(from: connection, connectionId: connectionId)
            }
        }
    }

    // MARK: - Broadcasting

    func broadcast(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(
            identifier: "textMessage",
            metadata: [metadata]
        )

        for (connectionId, connection) in connections {
            guard connection.state == .ready else {
                removeConnection(connectionId)
                continue
            }

            connection.send(
                content: data,
                contentContext: context,
                isComplete: true,
                completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ WebSocket broadcast error to client \(connectionId): \(error)")
                    }
                }
            )
        }
    }

    func sendTo(connectionId: Int, message: String) {
        guard let connection = connections[connectionId],
              let data = message.data(using: .utf8) else { return }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(
            identifier: "textMessage",
            metadata: [metadata]
        )

        connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { error in
                if let error = error {
                    print("❌ WebSocket send error to client \(connectionId): \(error)")
                }
            }
        )
    }
}
