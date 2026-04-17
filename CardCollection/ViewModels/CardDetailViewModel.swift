import Foundation
import SwiftUI

@MainActor
class CardDetailViewModel: ObservableObject {
    @Published var entry: CardEntryItem

    init(entry: CardEntryItem) {
        self.entry = entry
    }

    var profitDisplay: String? {
        guard let profit = entry.profit else { return nil }
        let sign = profit >= 0 ? "+" : ""
        return "\(sign)¥\(String(format: "%.2f", abs(profit)))"
    }

    var profitColor: Color { entry.profit ?? 0 >= 0 ? .green : .red }

    var formattedPurchasePrice: String? {
        guard let price = entry.purchasePrice else { return nil }
        return "¥\(String(format: "%.2f", price))"
    }

    var formattedSellPrice: String? {
        guard let price = entry.sellPrice else { return nil }
        return "¥\(String(format: "%.2f", price))"
    }

    var formattedPurchaseDate: String? {
        entry.purchaseDate?.formatted(date: .abbreviated, time: .omitted)
    }

    var formattedSellDate: String? {
        entry.sellDate?.formatted(date: .abbreviated, time: .omitted)
    }
}
