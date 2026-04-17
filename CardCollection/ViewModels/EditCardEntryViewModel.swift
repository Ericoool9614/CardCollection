import Foundation
import UIKit

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
    @Published var subcards: [SubCardItem]

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
        self.subcards = entry.subcards
    }

    func setLocalImage(at index: Int, image: UIImage) async {
        guard index < subcards.count else { return }
        let cardId = subcards[index].id
        do {
            let relativePath = try await ImageStorageService.shared.saveLocalImage(image, id: cardId)
            subcards[index].localImagePath = relativePath
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeLocalImage(at index: Int) async {
        guard index < subcards.count else { return }
        if let path = subcards[index].localImagePath {
            await ImageStorageService.shared.deleteImage(path: path)
        }
        subcards[index].localImagePath = nil
    }

    func saveEntry() {
        var updated = originalEntry
        updated.nickname = nickname.isEmpty ? nil : nickname
        updated.purchaseDate = purchasePrice > 0 ? purchaseDate : nil
        updated.purchasePrice = purchasePrice > 0 ? purchasePrice : nil
        updated.sellDate = hasSold ? sellDate : nil
        updated.sellPrice = hasSold ? sellPrice : nil
        updated.note = note.isEmpty ? nil : note
        updated.subcards = subcards

        let allEntries = persistence.fetchAllEntries()
        if let entry = allEntries.first(where: { $0.id == originalEntry.id }) {
            persistence.updateEntry(entry, with: updated)
            isSaved = true
        } else {
            errorMessage = "条目未找到"
        }
    }
}
