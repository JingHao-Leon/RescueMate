import Foundation
import CoreLocation

/// 高德能力抽象。当前实现是“用户自己的 Key 直连高德 REST”；
/// 日后如果改走自家服务器代理（Key 由服务端持有），实现一个同样的协议即可，界面不用动。
protocol AMapSearching {
    /// 按品类周边搜索
    func search(category: RescueCategory, near coordinate: CLLocationCoordinate2D, page: Int) async throws -> [POI]
    /// 按关键词周边搜索（搜索框输入）
    func search(keyword: String, near coordinate: CLLocationCoordinate2D, page: Int) async throws -> [POI]
    /// 补查单个 POI 的电话等详情
    func detail(id: String) async throws -> POI
    /// 逆地理编码：坐标 -> 地址文案
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String
}

enum RescueAPIError: LocalizedError {
    case missingKey
    case badServerResponse(String)
    case keyInvalid(String)
    case quotaExceeded(String)
    case serviceUnsupported(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "还没有配置高德 API Key。请到「设置」里按引导免费申请（2 分钟）。”"
        case .badServerResponse(let message):
            return "搜索失败：\(message)"
        case .keyInvalid(let message):
            return "API Key 无效：\(message)。请检查设置里粘贴的 Key（需为「Web服务」类型）"
        case .quotaExceeded(let message):
            return "今日免费额度已用完：\(message)。每位用户的 Key 各有独立额度，明天自动恢复，或换用自己的 Key"
        case .serviceUnsupported(let message):
            return "该 Key 不支持此服务：\(message)。申请 Key 时服务平台要选「Web服务」"
        }
    }

    static func from(infocode: String, info: String) -> RescueAPIError {
        switch infocode {
        case "10001", "10009", "1000A", "2000":
            return .keyInvalid(info)
        case "10003", "10044", "10019", "2003":
            return .quotaExceeded(info)
        case "10004", "10008":
            return .serviceUnsupported(info)
        default:
            return .badServerResponse("\(info)（错误码 \(infocode)）")
        }
    }
}

/// 高德 Web 服务 REST 客户端（搜索 2.0 v5 周边搜索 + v3 逆地理）。
final class AMapSearchClient: AMapSearching {
    static let searchBase = "https://restapi.amap.com/v5/place/around"
    static let detailBase = "https://restapi.amap.com/v5/place/detail"
    static let regeoBase = "https://restapi.amap.com/v3/geocode/regeo"

    private let session: URLSession

    init(session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        return URLSession(configuration: config)
    }()) {
        self.session = session
    }

    func search(category: RescueCategory, near coordinate: CLLocationCoordinate2D, page: Int) async throws -> [POI] {
        try await search(keyword: category.keywords, near: coordinate, page: page)
    }

    func search(keyword: String, near coordinate: CLLocationCoordinate2D, page: Int) async throws -> [POI] {
        var items = baseQuery()
        items.append(contentsOf: [
            URLQueryItem(name: "location", value: "\(coordinate.longitude),\(coordinate.latitude)"),
            URLQueryItem(name: "keywords", value: keyword),
            URLQueryItem(name: "radius", value: "10000"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "page_num", value: String(max(1, page))),
            URLQueryItem(name: "show_fields", value: "business"),
        ])
        return try await poisRequest(url: makeURL(Self.searchBase, items))
    }

    func detail(id: String) async throws -> POI {
        var items = baseQuery()
        items.append(URLQueryItem(name: "id", value: id))
        items.append(URLQueryItem(name: "show_fields", value: "business"))
        let url = makeURL(Self.detailBase, items)
        let dict = try await requestJSON(url: url)
        try Self.throwIfFailed(dict)
        guard var poi = Self.parsePOI(dict["poi"] as? [String: Any]) else {
            throw RescueAPIError.badServerResponse("详情数据解析失败")
        }
        poi.fetchedAt = Date()
        return poi
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        var items = baseQuery()
        items.append(contentsOf: [
            URLQueryItem(name: "location", value: "\(coordinate.longitude),\(coordinate.latitude)"),
            URLQueryItem(name: "extensions", value: "base"),
        ])
        let dict = try await requestJSON(url: makeURL(Self.regeoBase, items))
        try Self.throwIfFailed(dict)
        let regeocode = dict["regeocode"] as? [String: Any]
        return (regeocode?["formatted_address"] as? String) ?? ""
    }

    // MARK: - 内部

    private func baseQuery() -> [URLQueryItem] {
        guard let key = AMapConfig.currentKey(), !key.isEmpty else { return [] }
        return [URLQueryItem(name: "key", value: key)]
    }

    private func makeURL(_ base: String, _ items: [URLQueryItem]) -> URL {
        var components = URLComponents(string: base)!
        let encoded = items.map { item in
            URLQueryItem(name: item.name,
                         value: item.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        }
        components.queryItems = encoded.isEmpty ? nil : encoded
        return components.url!
    }

    private func poisRequest(url: URL) async throws -> [POI] {
        guard AMapConfig.currentKey() != nil else { throw RescueAPIError.missingKey }
        let dict = try await requestJSON(url: url)
        try Self.throwIfFailed(dict)
        let rawPois = dict["pois"] as? [[String: Any]] ?? []
        return rawPois.compactMap(Self.parsePOI)
    }

    private func requestJSON(url: URL) async throws -> [String: Any] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw RescueAPIError.badServerResponse("网络响应异常")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RescueAPIError.badServerResponse("HTTP \(http.statusCode)")
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any] else {
            throw RescueAPIError.badServerResponse("返回数据格式异常")
        }
        return dict
    }

    private static func throwIfFailed(_ dict: [String: Any]) throws {
        let status = dict["status"] as? String ?? "0"
        guard status == "1" else {
            let infocode = (dict["infocode"] as? String) ?? ""
            let info = (dict["info"] as? String) ?? "未知错误"
            throw RescueAPIError.from(infocode: infocode, info: info)
        }
    }

    /// 高德空字段有时返回 []，用 JSONSerialization 手工取值更稳。
    static func parsePOI(_ dict: [String: Any]?) -> POI? {
        guard let dict else { return nil }
        func str(_ key: String) -> String? {
            switch dict[key] {
            case let s as String: return s.isEmpty ? nil : s
            case let n as NSNumber: return n.stringValue
            default: return nil
            }
        }
        guard let id = str("id"), let name = str("name"), let location = str("location") else { return nil }
        let parts = location.split(separator: ",").map(String.init)
        guard parts.count == 2, let longitude = Double(parts[0]), let latitude = Double(parts[1]) else { return nil }
        let business = dict["business"] as? [String: Any]
        let tel = str("tel") ?? business.flatMap { $0["tel"] as? String }.flatMap { $0.isEmpty ? nil : $0 }
        let distance = str("distance").flatMap { Double($0) }
        return POI(id: id,
                   name: name,
                   address: str("address") ?? "",
                   tel: tel,
                   type: str("type"),
                   latitude: latitude,
                   longitude: longitude,
                   distanceMeters: distance,
                   fetchedAt: Date())
    }
}

/// 预留：服务器端代理实现。Info.plist 里配置 SERVER_API_BASE 后自动启用，
/// 约定接口（服务器持有 Key，帮所有用户省各自额度）：
///   GET {base}/around?key=<用户token>&lat=&lng=&keywords=&page=  ->  { "pois": [ {id,name,address,tel,type,location:"lng,lat",distance} ] }
///   GET {base}/detail?key=&id=                                   ->  { "poi": {...} }
///   GET {base}/regeo?key=&lat=&lng=                              ->  { "address": "..." }
final class ServerAMapClient: AMapSearching {
    private let baseURL: URL
    private let session = URLSession(configuration: .default)

    init(baseURL: URL) { self.baseURL = baseURL }

    func search(category: RescueCategory, near coordinate: CLLocationCoordinate2D, page: Int) async throws -> [POI] {
        try await search(keyword: category.keywords, near: coordinate, page: page)
    }

    func search(keyword: String, near coordinate: CLLocationCoordinate2D, page: Int) async throws -> [POI] {
        var components = URLComponents(url: baseURL.appendingPathComponent("around"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lng", value: String(coordinate.longitude)),
            URLQueryItem(name: "keywords", value: keyword),
            URLQueryItem(name: "page", value: String(page)),
        ]
        return try await decodePois(from: components.url!, rootKey: "pois")
    }

    func detail(id: String) async throws -> POI {
        var components = URLComponents(url: baseURL.appendingPathComponent("detail"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: id)]
        let dict = try await requestJSON(from: components.url!)
        guard var poi = AMapSearchClient.parsePOI(dict["poi"] as? [String: Any]) else {
            throw RescueAPIError.badServerResponse("详情数据解析失败")
        }
        poi.fetchedAt = Date()
        return poi
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        var components = URLComponents(url: baseURL.appendingPathComponent("regeo"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lng", value: String(coordinate.longitude)),
        ]
        let dict = try await requestJSON(from: components.url!)
        return dict["address"] as? String ?? ""
    }

    private func decodePois(from url: URL, rootKey: String) async throws -> [POI] {
        let dict = try await requestJSON(from: url)
        let rawPois = dict[rootKey] as? [[String: Any]] ?? []
        return rawPois.compactMap(AMapSearchClient.parsePOI)
    }

    private func requestJSON(from url: URL) async throws -> [String: Any] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RescueAPIError.badServerResponse("服务端 HTTP 错误")
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any] else {
            throw RescueAPIError.badServerResponse("服务端数据格式异常")
        }
        return dict
    }
}

enum AMapSearchFactory {
    /// 默认直连高德（用户自己的 Key）；配置了 SERVER_API_BASE 则走服务器代理。
    static var isServerProxyEnabled: Bool {
        guard let base = Bundle.main.object(forInfoDictionaryKey: "SERVER_API_BASE") as? String else { return false }
        return !base.isEmpty && URL(string: base) != nil
    }

    static func make() -> AMapSearching {
        if isServerProxyEnabled, let base = Bundle.main.object(forInfoDictionaryKey: "SERVER_API_BASE") as? String,
           let url = URL(string: base) {
            return ServerAMapClient(baseURL: url)
        }
        return AMapSearchClient()
    }
}
