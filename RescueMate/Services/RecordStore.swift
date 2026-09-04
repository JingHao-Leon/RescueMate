import Foundation

/// 离线事件记录仓库：本地 JSON 文件，增删即时落盘，不需要任何网络。
@MainActor
final class RecordStore: ObservableObject {
    @Published private(set) var records: [RescueRecord] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = fileURL ?? documents.appendingPathComponent("rescue_records.json")
        load()
    }

    func add(_ record: RescueRecord) {
        records.insert(record, at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        persist()
    }

    func delete(_ record: RescueRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([RescueRecord].self, from: data) else { return }
        records = list
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
