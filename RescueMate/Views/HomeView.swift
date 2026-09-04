import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment

    enum ResultState: Equatable {
        case idle
        case loading
        case online
        case cached(Date)
        case empty(String)
        case failed(String)
    }

    @State private var customKeyword = ""
    @State private var selectedCategory: RescueCategory?
    @State private var results: [POI] = []
    @State private var resultState: ResultState = .idle
    @State private var page = 1
    @State private var activeKeyword: String?
    @State private var activeCategoryID: String?
    @State private var lastErrorMessage: String?
    @State private var showSavedAlert = false
    @State private var focusedPOI: POI?
    @State private var recenterToken = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    statusBanner
                    locationCard
                    searchBox
                    categoryGrid
                    mapCard
                    resultSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("救援宝")
            .navigationBarTitleDisplayMode(.inline)
            .task { await env.refreshAddressIfNeeded() }
            .alert("已存入「离线记录」", isPresented: $showSavedAlert) {
                Button("好的", role: .cancel) {}
            }
        }
    }

    // MARK: - 顶部状态

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(env.network.isOnline ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(env.network.isOnline ? "在线 · 实时搜索（用你自己的高德额度）" : "离线模式 · 展示本地缓存")
                .font(.footnote)
            Spacer()
            if let last = env.location.lastOnlineLocation {
                Text("最后联网 " + Fmt.dateTime.string(from: last.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(env.network.isOnline ? Color.green.opacity(0.12) : Color.orange.opacity(0.15)))
    }

    private var locationCard: some View {
        let last = env.location.lastOnlineLocation
        let denied = env.location.authorizationStatus == .denied || env.location.authorizationStatus == .restricted
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Color.red)
                Text(env.network.isOnline ? "定位（联网时自动记录）" : "最后联网定位")
                    .font(.subheadline.bold())
                Spacer()
            }
            Text(locationText)
                .font(.callout)
                .foregroundStyle(denied ? Color.orange : Color.primary)
            if let last {
                Text("记录于 \(Fmt.fullDateTime.string(from: last.timestamp)) · 精度 ±\(Int(last.horizontalAccuracy))m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if denied {
                Button("去系统设置开启定位") { DeviceActions.openAppSettings() }
                    .font(.footnote.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var locationText: String {
        if let address = env.location.lastOnlineLocation?.address, !address.isEmpty {
            return address
        }
        if let coordinate = env.location.bestCoordinate {
            let source = env.location.lastFix == nil ? "来自上次记录" : "实时"
            return String(format: "%.5f, %.5f（%@）", coordinate.latitude, coordinate.longitude, source)
        }
        return "正在获取定位…请稍候"
    }

    // MARK: - 搜索框 + 品类

    private var searchBox: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索：拖车 / 24h汽修 / 发热门诊…", text: $customKeyword)
                .submitLabel(.search)
                .onSubmit { startCustomSearch() }
            if !customKeyword.isEmpty {
                Button {
                    customKeyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
            Button("搜索") { startCustomSearch() }
                .font(.subheadline.bold())
                .disabled(customKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("救援品类")
                .font(.subheadline.bold())
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(RescueCategory.all) { category in
                    Button {
                        customKeyword = ""
                        startCategorySearch(category)
                    } label: {
                        categoryChip(category)
                    }
                }
            }
        }
    }

    private func categoryChip(_ category: RescueCategory) -> some View {
        let isSelected = selectedCategory?.id == category.id
        return VStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(isSelected ? Color.red : Color.accentColor)
            Text(category.label)
                .font(.footnote.bold())
                .foregroundStyle(Color.primary)
            Text(category.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(isSelected ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground)))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(isSelected ? Color.red : Color.clear, lineWidth: 1.5))
    }

    // MARK: - 地图

    private var mapCard: some View {
        ZStack(alignment: .bottomTrailing) {
            POIMapView(pois: results,
                       focus: focusedPOI,
                       recenterToken: recenterToken,
                       fallbackCenter: env.location.bestCoordinate)
            Button {
                recenterToken += 1
            } label: {
                Image(systemName: "location.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.red)
                    .padding(10)
                    .background(Circle().fill(Color(.systemBackground)).shadow(radius: 2))
            }
            .padding(10)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 结果区

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            resultHeader
            switch resultState {
            case .idle:
                Text("点上方品类，或输入关键词搜索附近救援点；离线时自动使用缓存。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在搜索附近…").font(.footnote).foregroundStyle(.secondary)
                }
            case .empty(let message):
                Text(message).font(.footnote).foregroundStyle(.secondary)
            case .failed(let message):
                errorCard(message)
            case .online, .cached:
                ForEach(results) { poi in
                    POIRow(poi: poi,
                           amap: env.amap,
                           onUpdated: { updated in
                               results = results.map { $0.id == updated.id ? updated : $0 }
                           },
                           onSaveRecord: { saveRecord(poi) })
                    .contentShape(Rectangle())
                    .onTapGesture { focusedPOI = poi }
                    Divider()
                }
                if results.count >= 15 {
                    Button("加载更多") { loadMore() }
                        .font(.footnote.bold())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var resultHeader: some View {
        HStack {
            Text(resultTitle).font(.subheadline.bold())
            Spacer()
            switch resultState {
            case .online:
                Label("实时", systemImage: "wifi")
                    .font(.caption2).foregroundStyle(Color.green)
            case .cached(let date):
                Label("离线缓存 \(Fmt.dateTime.string(from: date))", systemImage: "clock.arrow.circlepath")
                    .font(.caption2).foregroundStyle(Color.orange)
            default:
                EmptyView()
            }
        }
    }

    private var resultTitle: String {
        if let category = selectedCategory {
            return "\(category.label) · 附近"
        }
        if activeKeyword != nil { return "搜索结果 · 附近" }
        return "附近救援点"
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("无法获取实时结果", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color.orange)
            Text(message).font(.footnote)
            Button("重试") { Task { await loadCurrentPage() } }
                .font(.footnote.bold())
        }
    }

    // MARK: - 搜索逻辑

    private func startCategorySearch(_ category: RescueCategory) {
        selectedCategory = category
        activeKeyword = category.keywords
        activeCategoryID = category.id
        page = 1
        results = []
        lastErrorMessage = nil
        Task { await loadCurrentPage() }
    }

    private func startCustomSearch() {
        let keyword = customKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        selectedCategory = nil
        activeKeyword = keyword
        activeCategoryID = "custom_search"
        page = 1
        results = []
        lastErrorMessage = nil
        Task { await loadCurrentPage() }
    }

    private func loadMore() {
        page += 1
        Task { await loadCurrentPage(appendOnly: true) }
    }

    private func loadCurrentPage(appendOnly: Bool = false) async {
        guard let keyword = activeKeyword, let categoryID = activeCategoryID else { return }
        guard let center = await bestCoordinateOrWait() else {
            resultState = .failed("还没有获取到定位：请允许定位权限，到开阔处稍等几秒再试。")
            return
        }
        if !appendOnly { resultState = .loading }

        if env.network.isOnline {
            do {
                let pois = try await env.amap.search(keyword: keyword, near: center, page: page)
                let sorted = Self.sorted(pois, near: center)
                if appendOnly {
                    results += sorted
                } else {
                    results = sorted
                }
                if !appendOnly, !sorted.isEmpty {
                    POICache.shared.save(POICacheEntry(categoryID: categoryID,
                                                       keyword: keyword,
                                                       centerLatitude: center.latitude,
                                                       centerLongitude: center.longitude,
                                                       pois: sorted,
                                                       fetchedAt: Date()))
                }
                resultState = results.isEmpty ? .empty("附近 10 公里内没有找到，换个关键词试试") : .online
                return
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
        loadFromCache(categoryID: categoryID, center: center)
    }

    private func loadFromCache(categoryID: String, center: CLLocationCoordinate2D) {
        if let entry = POICache.shared.nearest(categoryID: categoryID,
                                               latitude: center.latitude,
                                               longitude: center.longitude) {
            results = entry.pois
            resultState = .cached(entry.fetchedAt)
        } else {
            results = []
            let base = lastErrorMessage ?? (env.network.isOnline ? "搜索失败" : "当前离线")
            resultState = .failed("\(base)；附近也没有可用的离线缓存。")
        }
    }

    private func bestCoordinateOrWait() async -> CLLocationCoordinate2D? {
        for _ in 0..<16 {
            if let coordinate = env.location.bestCoordinate { return coordinate }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return env.location.bestCoordinate
    }

    static func sorted(_ pois: [POI], near center: CLLocationCoordinate2D) -> [POI] {
        pois.map { poi -> POI in
            var poi = poi
            if poi.distanceMeters == nil {
                poi.distanceMeters = Geo.distance(from: center, to: poi.coordinate)
            }
            return poi
        }
        .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
    }

    private func saveRecord(_ poi: POI) {
        let category = selectedCategory
        let record = RescueRecord(categoryID: category?.id ?? "custom_search",
                                  categoryLabel: category?.label ?? "收藏地点",
                                  note: "",
                                  poiName: poi.name,
                                  phone: poi.tel,
                                  latitude: poi.latitude,
                                  longitude: poi.longitude,
                                  address: poi.address)
        env.records.add(record)
        showSavedAlert = true
    }
}

extension POI {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
