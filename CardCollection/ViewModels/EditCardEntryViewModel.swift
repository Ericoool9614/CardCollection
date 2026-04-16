import Foundation

@MainActor
class EditCardEntryViewModel: ObservableObject {
    @Published var nickname = ""
    @Published var purchaseDate = Date()
    @Published var purchasePrice: Double = 0
    @Published var sellDate = Date()
    @Published var sellPrice: Double = 0
    @Published var hasSold = false
    @Published var note = ""
    @Published var isSaved = false
    @Published var errorMessage: String?

    private let persistence = PersistenceController.shared
    private var originalEntry: CardEntryItem

    init(entry: CardEntryItem) {
        self.originalEntry = entry
        self.nickname = entry.nickname ?? ""
        self.purchaseDate = entry.purchaseDate ?? Date()
        self.purchasePrice = entry.purchasePrice ?? 0
        self.sellDate = entry.sellDate ?? Date()
        self.sellPrice = entry.sellPrice ?? 0
        self.hasSold = entry.sellDate != nil
        self.note = entry.note ?? ""
    }

    func saveEntry() {
        var updated = originalEntry
        updated.nickname = nickname.isEmpty ? nil : nickname
        updated.purchaseDate = purchasePrice > 0 ? purchaseDate : nil
        updated.purchasePrice = purchasePrice > 0 ? purchasePrice : nil
        updated.sellDate = hasSold ? sellDate : nil
        updated.sellPrice = hasSold ? sellPrice : nil
        updated.note = note.isEmpty ? nil : note

        let allEntries = persistence.fetchAllEntries()
        if let entry = allEntries.first(where: { $0.id == originalEntry.id }) {
            persistence.updateEntry(entry, with: updated)
            isSaved = true
        } else {
            errorMessage = "Entry not found"
        }
    }
}
