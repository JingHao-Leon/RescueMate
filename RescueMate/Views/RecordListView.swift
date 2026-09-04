import SwiftUI

/// 离线事件记录列表：全本地存储，断网也能看、能记、能删。
struct RecordListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if env.records.records.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("还没有记录")
                            .font(.subheadline)
                        Text("抛锚、求助时随手记一笔，会自动带上最后一次定位，全程离线可用。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    List {
                        ForEach(env.records.records) { record in
                            recordRow(record)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        env.records.delete(record)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("离线记录")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddRecordSheet()
                    .environmentObject(env)
            }
        }
    }

    @ViewBuilder
    private func recordRow(_ record: RescueRecord) -> some View {
        let category = RescueCategory.byID(record.categoryID)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: category?.icon ?? "mappin.and.ellipse")
                    .foregroundStyle(Color.red)
                Text(record.categoryLabel)
                    .font(.subheadline.bold())
                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                Spacer()
                Text(Fmt.dateTime.string(from: record.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let poiName = record.poiName, !poiName.isEmpty {
                Text("地点：\(poiName)").font(.caption).foregroundStyle(.secondary)
            }
            if let address = record.address, !address.isEmpty {
                Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack {
                if let coordinateText = record.coordinateText {
                    Text(coordinateText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                Spacer()
                if let phone = record.phone, !phone.isEmpty {
                    Button {
                        DeviceActions.dial(phone)
                    } label: {
                        Label(phone, systemImage: "phone.fill")
                            .font(.caption.bold())
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// 手动记一笔：选类型 + 备注，自动附带最后一次定位。
struct AddRecordSheet: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var category: RescueCategory = .carRepair
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("事件类型") {
                    Picker("类型", selection: $category) {
                        ForEach(RescueCategory.all) { item in
                            Text(item.label).tag(item)
                        }
                    }
                }
                Section("备注") {
                    TextField("例如：高速抛锚，已在应急车道等待", text: $note, axis: .vertical)
                        .lineLimit(3)
                }
                Section {
                    LabeledContent("定位") {
                        Text(locationSummary)
                            .font(.caption)
                    }
                    if let address = env.location.lastOnlineLocation?.address, !address.isEmpty {
                        LabeledContent("地址") {
                            Text(address).font(.caption)
                        }
                    }
                } footer: {
                    Text("自动附带最后一次定位，离线状态也可以记录。")
                }
            }
            .navigationTitle("记一笔")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    private var locationSummary: String {
        if let fix = env.location.lastFix {
            return String(format: "%.5f, %.5f", fix.coordinate.latitude, fix.coordinate.longitude)
        }
        if let last = env.location.lastOnlineLocation {
            return String(format: "%.5f, %.5f（%@）", last.latitude, last.longitude, Fmt.dateTime.string(from: last.timestamp))
        }
        return "暂无定位"
    }

    private func save() {
        let fix = env.location.lastFix
        let last = env.location.lastOnlineLocation
        let record = RescueRecord(categoryID: category.id,
                                  categoryLabel: category.label,
                                  note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                  latitude: fix?.coordinate.latitude ?? last?.latitude,
                                  longitude: fix?.coordinate.longitude ?? last?.longitude,
                                  address: last?.address)
        env.records.add(record)
    }
}
