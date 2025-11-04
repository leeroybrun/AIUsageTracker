import Foundation
import VibeviewerModel

#if canImport(Network)
import Network

public actor DeveloperBridge {
    public static let shared = DeveloperBridge()

    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var lastSettings: AppSettings.Advanced?

    public init() {}

    public func update(snapshot: DashboardSnapshot?, settings: AppSettings) async {
        guard let snapshot else { return }
        if settings.advanced.enableDiagnosticsLogging {
            let export = snapshot.developerExport
            await writeExport(export)
        }
        if settings.advanced.enableDeveloperWebSocket {
            if lastSettings?.developerWebSocketPort != settings.advanced.developerWebSocketPort {
                await restartListener(port: UInt16(settings.advanced.developerWebSocketPort))
            } else if listener == nil {
                await restartListener(port: UInt16(settings.advanced.developerWebSocketPort))
            }
            await broadcast(snapshot: snapshot)
        } else {
            await stopListener()
        }
        lastSettings = settings.advanced
    }

    private func restartListener(port: UInt16) async {
        await stopListener()
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let wsOptions = NWProtocolWebSocket.Options()
            parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port) ?? .any)
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                self.addConnection(connection)
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            // swallow errors in headless environments
        }
    }

    private func addConnection(_ connection: NWConnection) {
        let identifier = ObjectIdentifier(connection)
        connections[identifier] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.sendHandshake(on: connection)
            case .failed, .cancelled:
                self.connections.removeValue(forKey: ObjectIdentifier(connection))
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    private func sendHandshake(on connection: NWConnection) {
        let payload = "{\"type\":\"hello\"}"
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "hello", metadata: [metadata])
        connection.send(content: payload.data(using: .utf8), contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func broadcast(snapshot: DashboardSnapshot) async {
        guard !connections.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "snapshot", metadata: [metadata])
        for (_, connection) in connections {
            connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
        }
    }

    private func stopListener() async {
        listener?.cancel()
        listener = nil
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
    }

    private func writeExport(_ export: DeveloperExport?) async {
        guard let export else { return }
        let fm = FileManager.default
        let url = URL(fileURLWithPath: export.exportPath)
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        struct Payload: Codable {
            let statusLine: String
            let lastWritten: Date
        }
        let payload = Payload(statusLine: export.statusLine, lastWritten: export.lastWritten)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: url, options: [.atomic])
        }
    }
}
#else

public actor DeveloperBridge {
    public static let shared = DeveloperBridge()

    public init() {}

    public func update(snapshot: DashboardSnapshot?, settings: AppSettings) async {
        guard let snapshot else { return }
        if settings.advanced.enableDiagnosticsLogging {
            let export = snapshot.developerExport
            await writeExport(export)
        }
    }

    private func writeExport(_ export: DeveloperExport?) async {
        guard let export else { return }
        let fm = FileManager.default
        let url = URL(fileURLWithPath: export.exportPath)
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        struct Payload: Codable {
            let statusLine: String
            let lastWritten: Date
        }
        let payload = Payload(statusLine: export.statusLine, lastWritten: export.lastWritten)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: url, options: [.atomic])
        }
    }
}

#endif
