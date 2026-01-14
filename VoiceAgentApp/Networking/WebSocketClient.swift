import Foundation

/// Protocol for WebSocket client events
protocol WebSocketClientDelegate: AnyObject {
    func webSocketDidConnect(_ client: WebSocketClient)
    func webSocketDidDisconnect(_ client: WebSocketClient, error: Error?)
    func webSocketDidReceiveData(_ client: WebSocketClient, data: Data)
    func webSocketDidReceiveText(_ client: WebSocketClient, text: String)
}

/// WebSocket client for connecting to DGX Spark backend over Tailscale
class WebSocketClient: NSObject {

    // MARK: - Properties

    weak var delegate: WebSocketClientDelegate?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var serverURL: URL

    private var reconnectAttempts = 0
    private let maxReconnectAttempts: Int
    private var reconnectTimer: Timer?
    private var isManuallyDisconnected = false
    private let autoReconnect: Bool
    private let connectionTimeout: TimeInterval

    var isConnected: Bool {
        return webSocketTask?.state == .running
    }

    // MARK: - Initialization

    init(serverURL: String,
         timeout: Int = 30,
         maxReconnectAttempts: Int = 5,
         autoReconnect: Bool = true) {
        // Default to Tailscale URL for DGX Spark
        guard let url = URL(string: serverURL) else {
            fatalError("Invalid server URL: \(serverURL)")
        }
        self.serverURL = url
        self.connectionTimeout = TimeInterval(timeout)
        self.maxReconnectAttempts = maxReconnectAttempts
        self.autoReconnect = autoReconnect
        super.init()

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = connectionTimeout
        configuration.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }

    // MARK: - Connection Management

    func connect() {
        guard webSocketTask == nil || webSocketTask?.state == .completed || webSocketTask?.state == .canceling else {
            print("WebSocket already connecting or connected")
            return
        }

        isManuallyDisconnected = false
        print("Connecting to WebSocket: \(serverURL.absoluteString)")

        var request = URLRequest(url: serverURL)
        request.timeoutInterval = connectionTimeout

        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()

        // Start receiving messages
        receiveMessage()
    }

    func disconnect() {
        print("Disconnecting WebSocket")
        isManuallyDisconnected = true
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Sending Data

    func send(data: Data, completion: @escaping (Error?) -> Void) {
        guard let task = webSocketTask, task.state == .running else {
            completion(WebSocketError.notConnected)
            return
        }

        let message = URLSessionWebSocketTask.Message.data(data)
        task.send(message) { error in
            if let error = error {
                print("Error sending data: \(error.localizedDescription)")
            }
            completion(error)
        }
    }

    func send(text: String, completion: @escaping (Error?) -> Void) {
        guard let task = webSocketTask, task.state == .running else {
            completion(WebSocketError.notConnected)
            return
        }

        let message = URLSessionWebSocketTask.Message.string(text)
        task.send(message) { error in
            if let error = error {
                print("Error sending text: \(error.localizedDescription)")
            }
            completion(error)
        }
    }

    // MARK: - Receiving Data

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.delegate?.webSocketDidReceiveData(self, data: data)
                case .string(let text):
                    self.delegate?.webSocketDidReceiveText(self, text: text)
                @unknown default:
                    print("Unknown message type received")
                }

                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                print("Error receiving message: \(error.localizedDescription)")
                self.handleDisconnection(error: error)
            }
        }
    }

    // MARK: - Reconnection Logic

    private func handleDisconnection(error: Error?) {
        delegate?.webSocketDidDisconnect(self, error: error)

        guard !isManuallyDisconnected else {
            print("Manual disconnection, not attempting reconnect")
            return
        }

        guard autoReconnect else {
            print("Auto-reconnect disabled")
            return
        }

        // 0 means unlimited reconnect attempts
        guard maxReconnectAttempts == 0 || reconnectAttempts < maxReconnectAttempts else {
            print("Max reconnection attempts reached")
            return
        }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // Exponential backoff, max 30s

        if maxReconnectAttempts == 0 {
            print("Attempting reconnection \(reconnectAttempts) (unlimited) in \(delay) seconds")
        } else {
            print("Attempting reconnection \(reconnectAttempts)/\(maxReconnectAttempts) in \(delay) seconds")
        }

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }

    private func resetReconnectionState() {
        reconnectAttempts = 0
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Configuration Info

    var currentServerURL: String {
        return serverURL.absoluteString
    }

    var currentTimeout: TimeInterval {
        return connectionTimeout
    }

    var currentMaxReconnectAttempts: Int {
        return maxReconnectAttempts
    }

    var isAutoReconnectEnabled: Bool {
        return autoReconnect
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketClient: URLSessionWebSocketDelegate {

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        resetReconnectionState()
        delegate?.webSocketDidConnect(self)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket closed with code: \(closeCode.rawValue)")
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) }
        print("Close reason: \(reasonString ?? "none")")

        let error = WebSocketError.connectionClosed(closeCode.rawValue, reasonString)
        handleDisconnection(error: error)
    }
}

// MARK: - URLSessionDelegate

extension WebSocketClient: URLSessionDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("URLSession task completed with error: \(error.localizedDescription)")
            handleDisconnection(error: error)
        }
    }
}

// MARK: - WebSocket Errors

enum WebSocketError: Error {
    case notConnected
    case connectionClosed(Int, String?)
    case invalidURL

    var localizedDescription: String {
        switch self {
        case .notConnected:
            return "WebSocket is not connected"
        case .connectionClosed(let code, let reason):
            return "WebSocket closed with code \(code): \(reason ?? "No reason provided")"
        case .invalidURL:
            return "Invalid WebSocket URL"
        }
    }
}
