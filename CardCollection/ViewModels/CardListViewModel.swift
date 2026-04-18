import Foundation

enum SortOption: String, CaseIterable, Sendable {
    case createdAt = "添加时间"
    case purchaseDate = "购买时间"
    case sellDate = "出售时间"
    case purchasePriceDesc = "购买价格(高→低)"
    case purchasePriceAsc = "购买价格(低→高)"
    case populationDesc = "Pop数(高→低)"
}

enum CardFilter: String, CaseIterable, Sendable {
    case all = "全部"
    case psa = "评级卡"
    case raw = "裸卡"
}

@MainActor
class CardListViewModel: ObservableObject {
    @Published var entries: [CardEntryItem] = []
    @Published var soldEntries: [CardEntryItem] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var sortOption: SortOption = .createdAt
    @Published var filter: CardFilter = .all
    @Published var selectedTab: Int = 0

    private let persistence = PersistenceController.shared

    var activeEntries: [CardEntryItem] {
        selectedTab == 0 ? entries : soldEntries
    }

    func loadEntries() {
        isLoading = true
        let allEntries = persistence.fetchAllEntries()
        var items = allEntries.map { $0.toItem() }

        if !searchText.isEmpty {
            items = items.filter { entry in
                (entry.nickname?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                entry.subcards.contains {
                    $0.name.localizedCaseInsensitiveContains(searchText) ||
                    ($0.set?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    ($0.number?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    ($0.psaCertNumber?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
            }
        }

        let unsold = items.filter { !$0.isSold }
        let sold = items.filter { $0.isSold }

        entries = applyFilter(unsold)
        soldEntries = applyFilter(sold)
        isLoading = false
    }

    private func applyFilter(_ items: [CardEntryItem]) -> [CardEntryItem] {
        var filtered = items
        switch filter {
        case .all:
            break
        case .psa:
            filtered = filtered.filter { $0.hasPSA }
        case .raw:
            filtered = filtered.filter { !$0.hasPSA }
        }
        return applySorting(filtered)
    }

    private func applySorting(_ items: [CardEntryItem]) -> [CardEntryItem] {
        switch sortOption {
        case .createdAt:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .purchaseDate:
            return items.sorted { ($0.purchaseDate ?? .distantPast) > ($1.purchaseDate ?? .distantPast) }
        case .sellDate:
            return items.filter { $0.sellDate != nil }.sorted { $0.sellDate! > $1.sellDate! }
                + items.filter { $0.sellDate == nil }
        case .purchasePriceDesc:
            return items.sorted { ($0.purchasePrice ?? 0) > ($1.purchasePrice ?? 0) }
        case .purchasePriceAsc:
            return items.sorted { ($0.purchasePrice ?? 0) < ($1.purchasePrice ?? 0) }
        case .populationDesc:
            return items.sorted { ($0.maxPopulation ?? 0) > ($1.maxPopulation ?? 0) }
        }
    }

    func deleteEntry(_ item: CardEntryItem) {
        let allEntries = persistence.fetchAllEntries()
        if let entry = allEntries.first(where: { $0.id == item.id }) {
            persistence.deleteEntry(entry)
            loadEntries()
        }
    }
}
