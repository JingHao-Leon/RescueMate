import Foundation
import CoreLocation

/// 定位服务：持续拿定位；**联网时**把最新定位写成“最后联网定位”并落盘，
/// 离线时沿用磁盘上的这条记录（GPS 本身不需要网络，但地址解析需要，所以离线只记坐标）。
final class LocationService: NSObject, ObservableObject {
    @Published var lastFix: CLLocation?
    @Published var lastOnlineLocation: LastKnownLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 由 AppEnvironment 注入，读网络状态
    var isOnline: () -> Bool = { true }

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        lastOnlineLocation = LastLocationFileStore.load()
        authorizationStatus = manager.authorizationStatus
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    /// 界面兜底用的“最佳已知坐标”：优先实时定位，其次最后联网定位。
    var bestCoordinate: CLLocationCoordinate2D? {
        if let fix = lastFix { return fix.coordinate }
        if let online = lastOnlineLocation { return online.coordinate }
        return nil
    }

    /// 联网状态下记录最后定位；离线时保留磁盘上的旧记录不动。
    private func handleUpdate(_ location: CLLocation) {
        lastFix = location
        guard isOnline() else { return }
        var entry = LastKnownLocation(location: location)
        entry.address = lastOnlineLocation?.address
        lastOnlineLocation = entry
        LastLocationFileStore.save(entry)
    }

    /// 逆地理编码成功后补写地址文案（只在联网时被调用）。
    func updateStoredAddress(_ address: String) {
        guard var entry = lastOnlineLocation, isOnline() else { return }
        entry.address = address
        lastOnlineLocation = entry
        LastLocationFileStore.save(entry)
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { self.handleUpdate(location) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { self.authorizationStatus = manager.authorizationStatus }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// “最后联网定位”的本地持久化（Application Support 下一个 JSON 文件，原子写入）。
enum LastLocationFileStore {
    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("last_online_location.json")
    }

    static func save(_ entry: LastKnownLocation, to url: URL = defaultURL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load(from url: URL = defaultURL) -> LastKnownLocation? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LastKnownLocation.self, from: data)
    }

    static func clear(fileURL: URL = defaultURL) {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
