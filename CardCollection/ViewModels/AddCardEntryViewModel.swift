import Foundation
import UIKit

@MainActor
class AddCardEntryViewModel: ObservableObject {
    @Published var subcards: [SubCardItem] = []
    @Published var selectedTab: Int = 0
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

    var canSave: Bool {
        !subcards.isEmpty && subcards.allSatisfy { !$0.name.isEmpty }
    }

    func addSubcard(isPSA: Bool = true) {
        let card = SubCardItem(
            id: UUID(),
            name: "",
            set: nil,
            number: nil,
            isPSA: isPSA,
            psaCertNumber: nil,
            grade: nil,
            population: nil,
            populationHigher: nil,
            psaImageFrontPath: nil,
            psaImageBackPath: nil,
            localImagePath: nil,
            year: nil,
            variety: nil,
            gradeDescription: nil,
            category: nil,
            labelType: nil,
            sortOrder: subcards.count
        )
        subcards.append(card)
        selectedTab = subcards.count - 1
    }

    func removeSubcard(at index: Int) {
        guard subcards.count > 1 else { return }
        subcards.remove(at: index)
        for i in subcards.indices { subcards[i].sortOrder = i }
        if selectedTab >= subcards.count { selectedTab = subcards.count - 1 }
    }

    func updateSubcard(_ item: SubCardItem) {
        if let idx = subcards.firstIndex(where: { $0.id == item.id }) {
            subcards[idx] = item
        }
    }

    func updateSubcard(at index: Int, _ update: (inout SubCardItem) -> Void) {
        guard index < subcards.count else { return }
        var card = subcards[index]
        update(&card)
        subcards[index] = card
    }

    func setSubcardName(at index: Int, _ name: String) {
        updateSubcard(at: index) { $0.name = name }
    }

    func setSubcardSet(at index: Int, _ set: String) {
        updateSubcard(at: index) { $0.set = set.isEmpty ? nil : set }
    }

    func setSubcardNumber(at index: Int, _ number: String) {
        updateSubcard(at: index) { $0.number = number.isEmpty ? nil : number }
    }

    func setSubcardCertNumber(at index: Int, _ cert: String) {
        updateSubcard(at: index) { $0.psaCertNumber = cert.isEmpty ? nil : cert }
    }

    func setLocalImage(at index: Int, image: UIImage) async {
        guard index < subcards.count else { return }
        let cardId = subcards[index].id
        do {
            let relativePath = try await ImageStorageService.shared.saveLocalImage(image, id: cardId)
            updateSubcard(at: index) { $0.localImagePath = relativePath }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeLocalImage(at index: Int) async {
        guard index < subcards.count else { return }
        if let path = subcards[index].localImagePath {
            await ImageStorageService.shared.deleteImage(path: path)
        }
        updateSubcard(at: index) { $0.localImagePath = nil }
    }

    func fetchPSAData(for index: Int) async {
        guard index < subcards.count else { return }
        let certNumber = subcards[index].psaCertNumber ?? ""
        guard !certNumber.isEmpty else {
            errorMessage = "Please enter a PSA cert number"
            return
        }

        do {
            let result = try await PSAService.shared.fetchCard(certNumber: certNumber)
            var card = subcards[index]
            card.isPSA = true
            card.psaCertNumber = certNumber
            card.name = result.cardName
            card.set = result.cardSet
            card.number = result.cardNumber
            card.grade = result.grade
            card.population = result.population
            card.populationHigher = result.populationHigher
            card.psaImageFrontPath = result.frontImagePath
            card.psaImageBackPath = result.backImagePath
            card.year = result.year
            card.variety = result.variety
            card.gradeDescription = result.gradeDescription
            card.category = result.category
            card.labelType = result.labelType
            subcards[index] = card
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveEntry() {
        guard canSave else { return }
        let item = CardEntryItem(
            id: UUID(),
            nickname: nickname.isEmpty ? nil : nickname,
            subcards: subcards,
            purchaseDate: purchasePrice > 0 ? purchaseDate : nil,
            purchasePrice: purchasePrice > 0 ? purchasePrice : nil,
            sellDate: hasSold ? sellDate : nil,
            sellPrice: hasSold ? sellPrice : nil,
            note: note.isEmpty ? nil : note,
            createdAt: Date(),
            updatedAt: Date()
        )
        persistence.createEntry(from: item)
        isSaved = true
    }
}
