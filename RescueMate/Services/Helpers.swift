import Foundation
import CoreLocation
import UIKit

enum Fmt {
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func distance(_ meters: Double?) -> String? {
        guard let meters else { return nil }
        if meters < 1000 { return String(format: "%.0f m", meters) }
        return String(format: "%.1f km", meters / 1000)
    }
}

enum Geo {
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }
}

/// 拨号与高德导航跳转。
enum DeviceActions {
    /// 拨打电话（真机生效；模拟器上无拨号能力）。
    static func dial(_ rawNumber: String) {
        let cleaned = rawNumber.filter { !$0.isWhitespace && $0 != "-" }
        guard let url = URL(string: "tel://\(cleaned)") else { return }
        UIApplication.shared.open(url)
    }

    /// 优先唤起高德地图 App 规划路线；没装高德则打开网页版。
    static func navigate(to poi: POI) {
        let name = poi.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let appURL = URL(string: "iosamap://path?sourceApplication=rescuemate&backScheme=rescuemate&dname=\(name)&dlat=\(poi.latitude)&dlon=\(poi.longitude)&dev=0&t=0")
        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
            return
        }
        let webURL = URL(string: "https://uri.amap.com/marker?position=\(poi.longitude),\(poi.latitude)&name=\(name)&src=rescuemate&callnative=1")
        if let webURL { UIApplication.shared.open(webURL) }
    }

    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
