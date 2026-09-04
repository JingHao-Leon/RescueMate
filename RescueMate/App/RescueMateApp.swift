import SwiftUI
import CoreLocation

@main
struct RescueMateApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .tint(Color(red: 0.86, green: 0.16, blue: 0.15))
        }
    }
}

/// 全局共享的服务容器：网络状态、定位、离线记录、高德接口。
@MainActor
final class AppEnvironment: ObservableObject {
    let network = NetworkMonitor()
    let location = LocationService()
    let records = RecordStore()
    let amap: AMapSearching = AMapSearchFactory.make()

    init() {
        // 只有联网时才把定位写成“最后联网定位”
        location.isOnline = { [weak network] in network?.isOnline ?? true }
        location.start()
    }

    /// 有网时顺手刷新一次“最后联网定位”的地址文案（限制频率，省接口配额）。
    func refreshAddressIfNeeded() async {
        guard network.isOnline, AMapConfig.currentKey() != nil else { return }
        guard let point = location.lastOnlineLocation ?? location.lastFix.map(LastKnownLocation.init) else { return }
        if let address = point.address, Date().timeIntervalSince(point.timestamp) < 600 { return }
        let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        guard let address = try? await amap.reverseGeocode(coordinate) else { return }
        location.updateStoredAddress(address)
    }
}

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedTab") private var selectedTab = 0
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "location.circle.fill") }
                .tag(0)
            RecordListView()
                .tabItem { Label("离线记录", systemImage: "list.clipboard") }
                .tag(1)
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            if !hasCompletedOnboarding { showOnboarding = true }
        }
        .onChange(of: hasCompletedOnboarding) { done in
            if done { env.location.requestPermission() }
        }
    }
}
