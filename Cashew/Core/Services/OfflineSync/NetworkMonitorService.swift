import Foundation
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitorService {

    static let shared = NetworkMonitorService()

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.cashew.network-monitor")
    private var observers: [UUID: (Bool) -> Void] = [:]

    private(set) var isOnline: Bool

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        self.isOnline = monitor.currentPath.status == .satisfied

        monitor.pathUpdateHandler = { [weak self] path in
            Self.forwardPathStatus(path.status, to: self)
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }

    func addObserver(_ observer: @escaping (Bool) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        observer(isOnline)
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    private func handlePathStatus(_ status: NWPath.Status) {
        let newValue = status == .satisfied
        guard isOnline != newValue else { return }
        isOnline = newValue
        for observer in observers.values {
            observer(newValue)
        }
    }

    private nonisolated static func forwardPathStatus(_ status: NWPath.Status, to monitor: NetworkMonitorService?) {
        Task { @MainActor in
            monitor?.handlePathStatus(status)
        }
    }
}
