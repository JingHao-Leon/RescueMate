import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var keyDraft = ""
    @State private var keyMessage: String?
    @State private var cacheBytes: Int64 = 0

    var body: some View {
        NavigationStack {
            Form {
                keySection
                emergencySection
                locationSection
                offlineSection
                aboutSection
            }
            .navigationTitle("设置")
            .onAppear { cacheBytes = POICache.shared.totalBytes() }
        }
    }

    // MARK: - 高德 Key

    private var keySection: some View {
        Section {
            HStack {
                Text("高德 API Key")
                Spacer()
                if let key = AMapConfig.currentKey() {
                    Text("已配置 · 尾号 \(key.suffix(4))")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                } else {
                    Text("未配置")
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
            }
            SecureField("粘贴 32 位 Key（Web服务）", text: $keyDraft)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            HStack {
                Button("保存 Key") { saveKey() }
                    .disabled(!AMapConfig.isValidKeyFormat(keyDraft))
                Spacer()
                if APIKeyStore.hasKey {
                    Button("删除已存 Key", role: .destructive) {
                        APIKeyStore.delete()
                        keyDraft = ""
                        keyMessage = "已删除。将回退到随包 Key（若有），否则只能离线使用。"
                    }
                }
            }
            if let keyMessage {
                Text(keyMessage).font(.caption).foregroundStyle(.secondary)
            }
            Link(destination: AMapConfig.consoleURL) {
                Label("去高德开放平台创建 Key", systemImage: "safari")
            }
            Link(destination: AMapConfig.guideURL) {
                Label("查看申请教程", systemImage: "book")
            }
            Button("重新看新手引导") { hasCompletedOnboarding = false }
        } header: {
            Text("高德地图接口")
        } footer: {
            Text("每位用户使用自己申请的 Key，互不占用免费额度。申请时服务平台务必选择「Web服务」。Key 只存在你手机的钥匙串里。")
        }
    }

    private func saveKey() {
        let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AMapConfig.isValidKeyFormat(key) else {
            keyMessage = "Key 应为 32 位字母数字组合，请检查。"
            return
        }
        APIKeyStore.save(key)
        keyDraft = ""
        keyMessage = "已保存，之后搜索都用你自己的免费额度。"
        Task { await env.refreshAddressIfNeeded() }
    }

    // MARK: - 紧急电话

    private var emergencySection: some View {
        Section {
            ForEach(EmergencyNumber.all) { item in
                Button {
                    DeviceActions.dial(item.number)
                } label: {
                    HStack {
                        Text(item.name).foregroundStyle(Color.primary)
                        Spacer()
                        Text(item.number)
                            .font(.callout.bold())
                            .foregroundStyle(Color.red)
                        Image(systemName: "phone.circle.fill")
                            .foregroundStyle(Color.green)
                    }
                }
            }
        } header: {
            Text("紧急电话（直拨，无需网络）")
        } footer: {
            Text("紧急情况请优先拨打以上电话；本 App 的搜索结果仅作辅助参考。")
        }
    }

    // MARK: - 定位

    private var locationSection: some View {
        Section {
            LabeledContent("定位权限") {
                Text(permissionText).font(.caption)
            }
            if env.location.authorizationStatus == .denied {
                Button("去系统设置开启") { DeviceActions.openAppSettings() }
            }
            if let last = env.location.lastOnlineLocation {
                LabeledContent("最后联网定位") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(last.address ?? String(format: "%.5f, %.5f", last.latitude, last.longitude))
                            .font(.caption)
                        Text(Fmt.fullDateTime.string(from: last.timestamp))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("定位")
        } footer: {
            Text("联网状态下每次拿到新定位都会覆盖保存，作为「最后联网定位」；离线后 App 继续使用这条记录。数据只保存在手机本地。")
        }
    }

    private var permissionText: String {
        switch env.location.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "已授权"
        case .denied, .restricted: return "已拒绝，去系统设置开启"
        case .notDetermined: return "未询问，回到首页会弹出"
        @unknown default: return "未知"
        }
    }

    // MARK: - 离线数据

    private var offlineSection: some View {
        Section {
            HStack {
                Text("附近搜索缓存")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            Button("清除搜索缓存", role: .destructive) {
                POICache.shared.clear()
                cacheBytes = POICache.shared.totalBytes()
            }
            HStack {
                Text("离线记录")
                Spacer()
                Text("\(env.records.records.count) 条").foregroundStyle(.secondary)
            }
        } header: {
            Text("离线数据")
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section {
            LabeledContent("版本") {
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
            LabeledContent("接口模式") {
                Text(AMapSearchFactory.isServerProxyEnabled ? "服务器代理" : "直连高德（用户自带 Key）")
                    .font(.caption)
            }
        } header: {
            Text("关于救援宝")
        } footer: {
            Text("救援宝 · 离线友好的自救互助工具。地图数据与搜索服务来自高德开放平台。")
        }
    }
}

struct EmergencyNumber: Identifiable {
    let id = UUID()
    let name: String
    let number: String

    static let all: [EmergencyNumber] = [
        .init(name: "报警", number: "110"),
        .init(name: "急救", number: "120"),
        .init(name: "交通事故", number: "122"),
        .init(name: "高速救援", number: "12122"),
    ]
}
