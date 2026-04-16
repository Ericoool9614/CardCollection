import Foundation

@MainActor
final class PriceHistoryService: Sendable {
    static let shared = PriceHistoryService()

    private let userDefaults = UserDefaults.standard
    private let priceHistoryKey = "priceHistory"

    private init() {}

    func addEntry(cardId: UUID, price: Double, source: String = "Manual") {
        var entries = loadEntries()
        let entry = PriceEntry(
            cardId: cardId,
            date: Date(),
            price: price,
            source: source
        )
        entries.append(entry)
        saveEntries(entries)
    }

    func loadEntries(for cardId: UUID) -> [PriceEntry] {
        loadEntries().filter { $0.cardId == cardId }.sorted { $0.date > $1.date }
    }

    func loadAllEntries() -> [PriceEntry] {
        loadEntries().sorted { $0.date > $1.date }
    }

    func deleteEntry(id: UUID) {
        var entries = loadEntries()
        entries.removeAll { $0.id == id }
        saveEntries(entries)
    }

    func deleteEntries(for cardId: UUID) {
        var entries = loadEntries()
        entries.removeAll { $0.cardId == cardId }
        saveEntries(entries)
    }

    private func loadEntries() -> [PriceEntry] {
        guard let data = userDefaults.data(forKey: priceHistoryKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([PriceEntry].self, from: data)
        } catch {
            return []
        }
    }

    private func saveEntries(_ entries: [PriceEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            userDefaults.set(data, forKey: priceHistoryKey)
        } catch {}
    }
}
