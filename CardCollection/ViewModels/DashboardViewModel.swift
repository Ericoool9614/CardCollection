import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var totalEntries: Int = 0
    @Published var totalCards: Int = 0
    @Published var totalInvestment: Double = 0
    @Published var totalProfit: Double = 0
    @Published var psaCount: Int = 0
    @Published var nonPSACount: Int = 0
    @Published var soldCount: Int = 0
    @Published var unsoldCount: Int = 0

    private let persistence = PersistenceController.shared

    func loadDashboard() {
        let entries = persistence.fetchAllEntries().map { $0.toItem() }

        totalEntries = entries.count
        totalCards = entries.reduce(0) { $0 + $1.cardCount }
        psaCount = entries.reduce(0) { $0 + $1.subcards.filter { $0.isPSA }.count }
        nonPSACount = totalCards - psaCount
        soldCount = entries.filter { $0.isSold }.count
        unsoldCount = entries.filter { !$0.isSold }.count

        totalInvestment = entries.reduce(0) { $0 + ($1.purchasePrice ?? 0) }
        totalProfit = entries.filter { $0.isSold }.reduce(0) {
            $0 + (($1.sellPrice ?? 0) - ($1.purchasePrice ?? 0))
        }
    }

    func formatted(_ value: Double) -> String {
        if abs(value) >= 10000 {
            return String(format: "¥%.0f", value)
        } else if abs(value) >= 1000 {
            return String(format: "¥%.0f", value)
        }
        return String(format: "¥%.2f", value)
    }
}
