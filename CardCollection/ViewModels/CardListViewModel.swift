import Foundation

@MainActor
class CardListViewModel: ObservableObject {
    @Published var entries: [CardEntryItem] = []
    @Published var searchText = ""
    @Published var isLoading = false

    private let persistence = PersistenceController.shared

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
                    ($0.number?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
            }
        }

        entries = items
        isLoading = false
    }

    func deleteEntry(_ item: CardEntryItem) {
        let allEntries = persistence.fetchAllEntries()
        if let entry = allEntries.first(where: { $0.id == item.id }) {
            persistence.deleteEntry(entry)
            loadEntries()
        }
    }
}
