import Foundation

struct PriceEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let cardId: UUID
    let date: Date
    let price: Double
    let source: String

    static func == (lhs: PriceEntry, rhs: PriceEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(id: UUID = UUID(), cardId: UUID, date: Date, price: Double, source: String) {
        self.id = id
        self.cardId = cardId
        self.date = date
        self.price = price
        self.source = source
    }
}
