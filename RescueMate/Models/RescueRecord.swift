import Foundation

/// 离线事件记录：抛锚/求助时随手记一条，含当时的最后定位，全程不需要网络。
struct RescueRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var categoryID: String
    var categoryLabel: String
    var note: String
    var poiName: String?
    var phone: String?
    var latitude: Double?
    var longitude: Double?
    var address: String?

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         categoryID: String,
         categoryLabel: String,
         note: String = "",
         poiName: String? = nil,
         phone: String? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil,
         address: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.categoryID = categoryID
        self.categoryLabel = categoryLabel
        self.note = note
        self.poiName = poiName
        self.phone = phone
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }

    var coordinateText: String? {
        guard let latitude, let longitude else { return nil }
        return String(format: "%.5f, %.5f", latitude, longitude)
    }
}
