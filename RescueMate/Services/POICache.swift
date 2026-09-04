import Foundation
import CoreLocation

/// 每次联网搜索成功，把结果按「品类 + 约1公里格网」缓存成文件；
/// 离线时拿最后定位去找 8 公里内最近的缓存，展示“上次联网时的附近救援点”。
struct POICacheEntry: Codable, Equatable {
    var categoryID: String
    var keyword: String
    var centerLatitude: Double
    var centerLongitude: Double
    var pois: [POI]
    var fetchedAt: Date
}

final class POICache {
    static let shared = POICache()
    static let gridScale = 100.0 // 0.01 度 ≈ 1.1 km 格网
    static let maxReuseDistance: Double = 8_000

    private let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("poi_cache", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    static func gridValue(_ value: Double) -> Int {
        Int((value * gridScale).rounded())
    }

    static func fileName(categoryID: String, gridLat: Int, gridLon: Int) -> String {
        "\(categoryID)_\(gridLat)_\(gridLon).json"
    }

    func save(_ entry: POICacheEntry) {
        let name = Self.fileName(categoryID: entry.categoryID,
                                 gridLat: Self.gridValue(entry.centerLatitude),
                                 gridLon: Self.gridValue(entry.centerLongitude))
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    /// 找离当前位置最近、且在 maxReuseDistance 内的缓存条目。
    func nearest(categoryID: String, latitude: Double, longitude: Double) -> POICacheEntry? {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let prefix = "\(categoryID)_"
        let origin = CLLocation(latitude: latitude, longitude: longitude)
        var best: (entry: POICacheEntry, distance: Double)?
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            guard let data = try? Data(contentsOf: file),
                  let entry = try? JSONDecoder().decode(POICacheEntry.self, from: data) else { continue }
            let distance = origin.distance(from: CLLocation(latitude: entry.centerLatitude,
                                                            longitude: entry.centerLongitude))
            if distance <= Self.maxReuseDistance, distance < (best?.distance ?? .greatestFiniteMagnitude) {
                best = (entry, distance)
            }
        }
        return best?.entry
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func totalBytes() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.reduce(0) { total, file in
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
}
