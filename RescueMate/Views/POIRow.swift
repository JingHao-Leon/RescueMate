import SwiftUI

/// 结果列表的单行：名称、急诊标记、距离、地址、拨打/导航/存记录。
struct POIRow: View {
    let poi: POI
    let amap: AMapSearching
    var onUpdated: (POI) -> Void
    var onSaveRecord: () -> Void

    @State private var loadingTel = false
    @State private var showNoTelAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text(poi.name)
                    .font(.headline)
                if poi.hasEmergency {
                    Text("急诊")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                        .foregroundStyle(Color.orange)
                }
                Spacer()
                if let distance = Fmt.distance(poi.distanceMeters) {
                    Text(distance)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.red)
                }
            }
            if !poi.address.isEmpty {
                Text(poi.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 10) {
                Button { Task { await handleCall() } } label: {
                    HStack(spacing: 4) {
                        if loadingTel {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "phone.fill")
                        }
                        Text(poi.tel?.isEmpty == false ? "拨打" : "查电话")
                    }
                    .font(.footnote.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
                    .foregroundStyle(Color.green)
                }
                .disabled(loadingTel)

                Button { DeviceActions.navigate(to: poi) } label: {
                    Label("导航", systemImage: "map.fill")
                        .font(.footnote.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.blue.opacity(0.12)))
                        .foregroundStyle(Color.blue)
                }

                Spacer()

                Button(action: onSaveRecord) {
                    Label("存记录", systemImage: "square.and.arrow.down")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .alert("该地点没有登记电话", isPresented: $showNoTelAlert) {
            Button("好的", role: .cancel) {}
        }
    }

    private func handleCall() async {
        if let tel = poi.tel, !tel.isEmpty {
            DeviceActions.dial(tel)
            return
        }
        loadingTel = true
        defer { loadingTel = false }
        guard let detailed = try? await amap.detail(id: poi.id),
              let tel = detailed.tel, !tel.isEmpty else {
            showNoTelAlert = true
            return
        }
        onUpdated(detailed)
        DeviceActions.dial(tel)
    }
}
