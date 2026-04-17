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
    @Published var isFetchingPSA = false

    private let persistence = PersistenceController.shared

    var canSave: Bool {
        !subcards.isEmpty && subcards.allSatisfy { !$0.name.isEmpty }
    }

    func indexOfCard(_ card: SubCardItem) -> Int {
        subcards.firstIndex(where: { $0.id == card.id }) ?? 0
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

    func removeSubcard(id: UUID) {
        guard subcards.count > 1 else { return }
        subcards.removeAll { $0.id == id }
        for i in subcards.indices { subcards[i].sortOrder = i }
        if selectedTab >= subcards.count { selectedTab = subcards.count - 1 }
    }

    func removeSubcard(at index: Int) {
        guard subcards.count > 1, index < subcards.count else { return }
        subcards.remove(at: index)
        for i in subcards.indices { subcards[i].sortOrder = i }
        if selectedTab >= subcards.count { selectedTab = subcards.count - 1 }
    }

    func setSubcardCertNumber(id: UUID, _ cert: String) {
        guard let idx = subcards.firstIndex(where: { $0.id == id }) else { return }
        var card = subcards[idx]
        card.psaCertNumber = cert.isEmpty ? nil : cert
        subcards[idx] = card
    }

    func setSubcardCertNumber(at index: Int, _ cert: String) {
        guard index < subcards.count else { return }
        var card = subcards[index]
        card.psaCertNumber = cert.isEmpty ? nil : cert
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

    func fetchPSACard(id: UUID) async {
        guard let index = subcards.firstIndex(where: { $0.id == id }) else { return }
        await fetchPSACard(at: index)
    }

    func fetchPSACard(at index: Int) async {
        guard index < subcards.count else { return }
        let certNumber = subcards[index].psaCertNumber ?? ""
        guard !certNumber.isEmpty else {
            errorMessage = "请输入PSA认证编号"
            return
        }

        let existingCertNumbers = persistence.fetchAllEntries()
            .flatMap { $0.subcardsSorted }
            .compactMap { $0.psaCertNumber }
        if existingCertNumbers.contains(certNumber) {
            errorMessage = "认证编号 \(certNumber) 的评级卡已存在，请勿重复添加"
            return
        }

        let currentSubcards = subcards
        let duplicateInForm = currentSubcards.enumerated().filter {
            $0.offset != index && $0.element.psaCertNumber == certNumber
        }
        if !duplicateInForm.isEmpty {
            errorMessage = "认证编号 \(certNumber) 已在当前条目中添加"
            return
        }

        isFetchingPSA = true
        defer { isFetchingPSA = false }

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
            updatedAt: Date(),
            askingPrice: nil
        )
        persistence.createEntry(from: item)
        isSaved = true
    }
}
