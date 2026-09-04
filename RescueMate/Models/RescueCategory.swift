import Foundation

/// 搜索框下方的救援品类。
struct RescueCategory: Identifiable, Hashable {
    let id: String
    let icon: String
    let label: String
    let subtitle: String
    /// 高德“周边搜索”的 keywords，多个词用 | 分隔
    let keywords: String

    static func byID(_ id: String) -> RescueCategory? { all.first { $0.id == id } }
}

extension RescueCategory {
    static let carRepair = RescueCategory(
        id: "car_repair", icon: "wrench.and.screwdriver.fill",
        label: "汽修救援", subtitle: "抛锚·维修",
        keywords: "汽车维修|汽车救援|汽修|4s店")
    static let towing = RescueCategory(
        id: "towing", icon: "car.fill",
        label: "拖车", subtitle: "道路救援",
        keywords: "拖车|道路救援")
    static let hospital = RescueCategory(
        id: "hospital", icon: "cross.case.fill",
        label: "医院急诊", subtitle: "急诊·急救",
        keywords: "医院|急诊|急救中心")
    static let gasStation = RescueCategory(
        id: "gas_station", icon: "fuelpump.fill",
        label: "加油站", subtitle: "就近加油",
        keywords: "加油站")
    static let charging = RescueCategory(
        id: "charging", icon: "bolt.fill",
        label: "充电桩", subtitle: "电车充电",
        keywords: "充电站|充电桩")
    static let police = RescueCategory(
        id: "police", icon: "shield.fill",
        label: "派出所", subtitle: "报警求助",
        keywords: "派出所|交警大队")

    static let all: [RescueCategory] = [carRepair, towing, hospital, gasStation, charging, police]
}
