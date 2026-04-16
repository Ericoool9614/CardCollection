import Foundation

@MainActor
class PriceHistoryViewModel: ObservableObject {
    @Published var entries: [PriceEntry] = []
    @Published var newPrice: Double = 0
    @Published var newSource: String = "Manual"

    private let service = PriceHistoryService.shared
    private let cardId: UUID

    init(cardId: UUID) {
        self.cardId = cardId
        loadEntries()
    }

    func loadEntries() {
        entries = service.loadEntries(for: cardId)
    }

    func addEntry() {
        guard newPrice > 0 else { return }
        service.addEntry(cardId: cardId, price: newPrice, source: newSource)
        newPrice = 0
        newSource = "Manual"
        loadEntries()
    }

    func deleteEntry(_ entry: PriceEntry) {
        service.deleteEntry(id: entry.id)
        loadEntries()
    }

    var priceChange: Double? {
        guard entries.count >= 2 else { return nil }
        let sorted = entries.sorted { $0.date < $1.date }
        return sorted.last!.price - sorted.first!.price
    }

    var priceChangeDisplay: String? {
        guard let change = priceChange else { return nil }
        let sign = change >= 0 ? "+" : ""
        return "\(sign)$\(String(format: "%.2f", change))"
    }

    var priceChangeColor: String {
        guard let change = priceChange else { return "gray" }
        return change >= 0 ? "green" : "red"
    }
}
