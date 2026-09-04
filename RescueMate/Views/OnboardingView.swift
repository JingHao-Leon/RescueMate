import SwiftUI

/// 首次启动引导：讲清楚离线能力 + 带每位用户去高德免费申请自己的 Key。
struct OnboardingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var keyDraft = ""
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    featureCards
                    applySteps
                    keyInput
                    skipRow
                }
                .padding(20)
            }
        }
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.largeTitle)
                    .foregroundStyle(Color.red)
                Text("救援宝")
                    .font(.largeTitle.bold())
            }
            Text("抛锚 / 求助时的救援助手。界面只有一个搜索框和几个品类，离线也能用。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var featureCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "wifi.slash", color: .orange,
                       title: "离线可用",
                       text: "联网时自动记录最后一次定位；搜索结果、事件记录都保存在手机里，断网照样能查能记。")
            featureRow(icon: "key.horizontal", color: .blue,
                       title: "用你自己的免费高德额度",
                       text: "每位用户在 App 内粘贴自己申请的高德 Key，额度互不占用。")
            featureRow(icon: "phone.fill", color: .green,
                       title: "一键找到修理店和医院",
                       text: "搜索框下方就是品类：汽修救援、拖车、医院（标记急诊）、加油站、充电桩、派出所，结果直接显示电话。")
        }
    }

    private func featureRow(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var applySteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("三步申请 Key（免费，约 2 分钟）")
                .font(.subheadline.bold())
            stepRow(1, text: "点下方按钮，注册/登录高德开放平台")
            stepRow(2, text: "控制台 → 应用管理 → 创建新应用 → 添加 Key")
            stepRow(3, text: "服务平台选择「Web服务」，复制生成的 32 位 Key")
            Link(destination: AMapConfig.consoleURL) {
                Label("打开高德开放平台", systemImage: "arrow.up.right.square.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGroupedBackground)))
    }

    private func stepRow(_ index: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index)")
                .font(.caption2.bold())
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.red))
                .foregroundStyle(Color.white)
            Text(text).font(.footnote)
        }
    }

    private var keyInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已有 Key？粘贴到这里")
                .font(.subheadline.bold())
            SecureField("粘贴 32 位 Key", text: $keyDraft)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if let message {
                Text(message).font(.caption).foregroundStyle(Color.orange)
            }
            Button {
                finishWithKey()
            } label: {
                Text("保存并开始使用")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!AMapConfig.isValidKeyFormat(keyDraft))
        }
    }

    private var skipRow: some View {
        Button {
            hasCompletedOnboarding = true
            dismiss()
        } label: {
            Text("跳过，先用离线模式（可稍后在「设置」里配置 Key）")
                .font(.footnote)
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 16)
    }

    private func finishWithKey() {
        let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AMapConfig.isValidKeyFormat(key) else {
            message = "Key 应为 32 位字母数字组合，请检查是否复制完整。"
            return
        }
        APIKeyStore.save(key)
        hasCompletedOnboarding = true
        Task { await env.refreshAddressIfNeeded() }
        dismiss()
    }
}
