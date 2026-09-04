import Foundation

/// 兴趣点（修理店 / 医院 / 加油站…）。由高德接口返回，也可来自离线缓存。
struct POI: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var address: String
    var tel: String?
    var type: String?
    var latitude: Double
    var longitude: Double
    /// 高德周边搜索直接返回的“距离多少米”，可能为空
    var distanceMeters: Double?
    var fetchedAt: Date

    /// 医院/急诊可用性判定：名字或类型带「急诊/急救」直接标记；
    /// 综合医院按国家规范设 24 小时急诊，也视为有急诊（专科医院不一定有）。
    var hasEmergency: Bool {
        let text = name + " " + (type ?? "")
        if text.contains("急诊") || text.contains("急救") { return true }
        return text.contains("综合医院")
    }
}

/// 最后一次联网时记录下来的定位，本地持久化。
struct LastKnownLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var timestamp: Date
    var address: String?

    init(latitude: Double, longitude: Double, horizontalAccuracy: Double, timestamp: Date, address: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
        self.address = address
    }
}

extension LastKnownLocation {
    init(location: CLLocation) {
        self.init(latitude: location.coordinate.latitude,
                  longitude: location.coordinate.longitude,
                  horizontalAccuracy: location.horizontalAccuracy,
                  timestamp: Date())
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

import CoreLocation
