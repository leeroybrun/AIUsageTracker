import Foundation
import VibeviewerModel

#if canImport(Network)
import Network

public actor UsageProxyServer {
    public static let shared = UsageProxyServer()

    private var listener: NWListener?
    private let cache: IncrementalUsageCache
    private var retentionDays: Int = 14

    public init(cache: IncrementalUsageCache = .shared) {
        self.cache = cache
    }

    public func start(port: UInt16, retentionDays: Int) async {
        self.retentionDays = retentionDays
        if listener != nil { await stop() }
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port) ?? .any)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            // fail silently; the feature is optional
        }
    }

    public func stop() async {
        listener?.cancel()
        listener = nil
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .main)
        connection.receiveMessage { [weak self] data, _, isComplete, _ in
            guard let self, let data else {
                connection.cancel()
                return
            }
            Task { await self.ingest(data: data) }
            if isComplete { connection.cancel() }
        }
    }

    private func ingest(data: Data) async {
        guard let payload = parseHTTPBody(data: data) else { return }
        guard let envelope = try? JSONDecoder().decode(ProxyEnvelope.self, from: payload) else { return }
        try? await cache.append(newEvents: envelope.events, retentionDays: retentionDays)
    }

    private func parseHTTPBody(data: Data) -> Data? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        guard let separatorRange = raw.range(of: "\r\n\r\n") else { return nil }
        let body = raw[separatorRange.upperBound...]
        return body.data(using: .utf8)
    }

    private struct ProxyEnvelope: Codable {
        let events: [UsageEvent]
    }
}
#else

public actor UsageProxyServer {
    public static let shared = UsageProxyServer()

    public func start(port: UInt16, retentionDays: Int) async {}
    public func stop() async {}
}

#endif
