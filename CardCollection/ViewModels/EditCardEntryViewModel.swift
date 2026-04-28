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
    @Published var language: String

    private let persistence: PersistenceController
    private var entryId: UUID

    init(entry: CardEntryItem, persistence: PersistenceController = .shared) {
        self.entryId = entry.id
        self.persistence = persistence
        self.nickname = entry.nickname ?? ""
        self.purchaseDate = entry.purchaseDate ?? Date()
        self.purchasePrice = entry.purchasePrice ?? 0
        self.sellDate = entry.sellDate ?? Date()
        self.sellPrice = entry.sellPrice ?? 0
        self.hasSold = entry.sellDate != nil
        self.note = entry.note ?? ""
        self.subcards = entry.subcards.map { card in
            var validatedCard = card
            if validatedCard.gradingCompany.isEmpty {
                validatedCard.gradingCompany = GradingCompany.default.rawValue
            }
            if card.isPSA {
                let company = card.gradingCompanyEnum
                if !company.isFreeTextInput,
                   let grade = card.grade, !grade.isEmpty,
                   !company.gradeOptions.contains(grade) {
                    validatedCard.grade = nil
                }
            }
            return validatedCard
        }
        self.language = entry.language
    }

    func updateSubcardName(at index: Int, _ value: String) {
        guard index < subcards.count else { return }
        var card = subcards[index]
        card.name = value
        subcards[index] = card
    }

    func updateSubcardSet(at index: Int, _ value: String) {
        guard index < subcards.count else { return }
        var card = subcards[index]
        card.set = value.isEmpty ? nil : value
        subcards[index] = card
    }

    func updateSubcardNumber(at index: Int, _ value: String) {
        guard index < subcards.count else { return }
        var card = subcards[index]
        card.number = value.isEmpty ? nil : value
        subcards[index] = card
    }

    func updateSubcardGrade(at index: Int, _ value: String?) {
        guard index < subcards.count else { return }
        var card = subcards[index]
        card.grade = value
        if let g = value, !g.isEmpty {
            card.gradeDescription = "\(card.gradingCompany) \(g)"
        }
        subcards[index] = card
    }

    func updateSubcardGradingCompany(at index: Int, _ value: String) {
        guard index < subcards.count else { return }
        var card = subcards[index]
        card.gradingCompany = value
        if let g = card.grade, !g.isEmpty {
            card.gradeDescription = "\(value) \(g)"
        }
        if GradingCompany(rawValue: value)?.isFreeTextInput == true {
            card.grade = nil
        } else if let g = card.grade, !GradingCompany(rawValue: value)!.gradeOptions.contains(g) {
            card.grade = nil
        }
        subcards[index] = card
    }

    func setLocalImage(at index: Int, image: UIImage) async {
        guard index < subcards.count else { return }
        let cardId = subcards[index].id
        do {
            let relativePath = try await ImageStorageService.shared.saveLocalImage(image, id: cardId)
            var card = subcards[index]
            card.localImagePath = relativePath
            subcards[index] = card
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeLocalImage(at index: Int) async {
        guard index < subcards.count else { return }
        if let path = subcards[index].localImagePath {
            await ImageStorageService.shared.deleteImage(path: path)
        }
        var card = subcards[index]
        card.localImagePath = nil
        subcards[index] = card
    }

    func saveEntry() {
        var updated = CardEntryItem(
            id: entryId,
            nickname: nickname.isEmpty ? nil : nickname,
            subcards: subcards,
            purchaseDate: purchasePrice > 0 ? purchaseDate : nil,
            purchasePrice: purchasePrice > 0 ? purchasePrice : nil,
            sellDate: hasSold ? sellDate : nil,
            sellPrice: hasSold ? sellPrice : nil,
            note: note.isEmpty ? nil : note,
            createdAt: Date(),
            updatedAt: Date(),
            language: language
        )

        let allEntries = persistence.fetchAllEntries()
        if let entry = allEntries.first(where: { $0.id == entryId }) {
            persistence.updateEntry(entry, with: updated)
            isSaved = true
        } else {
            persistence.createEntry(from: updated)
            isSaved = true
        }
    }
}
