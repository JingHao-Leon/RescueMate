import Foundation
import Network

/// 网络可达性监控：决定“是否记录最后联网定位”“是否可以直连高德”。
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                self?.isOnline = online
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.rescuemate.network"))
    }

    deinit { monitor.cancel() }
}
