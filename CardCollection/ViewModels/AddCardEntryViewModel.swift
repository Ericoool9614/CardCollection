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
    @Published var fetchingCardIds: Set<UUID> = []
    @Published var showBatchAdd = false
    @Published var batchStartNumber = ""
    @Published var batchEndNumber = ""
    @Published var batchProgress: Double = 0
    @Published var isBatchFetching = false

    private let persistence = PersistenceController.shared

    var canSave: Bool {
        !subcards.isEmpty && subcards.allSatisfy { !$0.name.isEmpty }
    }

    func isFetching(id: UUID) -> Bool {
        fetchingCardIds.contains(id)
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

    func addSubcardWithCertNumber(_ certNumber: String) {
        let card = SubCardItem(
            id: UUID(),
            name: "",
            set: nil,
            number: nil,
            isPSA: true,
            psaCertNumber: certNumber,
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
        let cardId = subcards[index].id
        let certNumber = subcards[index].psaCertNumber ?? ""
        guard !certNumber.isEmpty else {
            errorMessage = "请输入PSA认证编号"
            return
        }

        if checkDuplicateCert(certNumber, excludeIndex: index) { return }

        fetchingCardIds.insert(cardId)

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

        fetchingCardIds.remove(cardId)
    }

    private func checkDuplicateCert(_ certNumber: String, excludeIndex: Int) -> Bool {
        let existingCertNumbers = persistence.fetchAllEntries()
            .flatMap { $0.subcardsSorted }
            .compactMap { $0.psaCertNumber }
        if existingCertNumbers.contains(certNumber) {
            errorMessage = "认证编号 \(certNumber) 的评级卡已存在，请勿重复添加"
            return true
        }

        let duplicateInForm = subcards.enumerated().filter {
            $0.offset != excludeIndex && $0.element.psaCertNumber == certNumber
        }
        if !duplicateInForm.isEmpty {
            errorMessage = "认证编号 \(certNumber) 已在当前条目中添加"
            return true
        }

        return false
    }

    func batchFetchPSACards() async {
        guard let startNum = Int(batchStartNumber),
              let endNum = Int(batchEndNumber),
              startNum <= endNum else {
            errorMessage = "请输入有效的起始和结束编号"
            return
        }

        let totalCount = endNum - startNum + 1
        if totalCount > 100 {
            errorMessage = "单次批量添加不超过100张"
            return
        }

        isBatchFetching = true
        batchProgress = 0

        subcards.removeAll { $0.name.isEmpty && $0.psaCertNumber == nil }

        var certNumbers: [String] = []
        for num in startNum...endNum {
            certNumbers.append(String(num))
        }

        let existingCerts = Set(persistence.fetchAllEntries()
            .flatMap { $0.subcardsSorted }
            .compactMap { $0.psaCertNumber })
        let existingInForm = Set(subcards.compactMap { $0.psaCertNumber })
        let allExisting = existingCerts.union(existingInForm)

        let newCertNumbers = certNumbers.filter { !allExisting.contains($0) }
        if newCertNumbers.count < certNumbers.count {
            let skipped = certNumbers.count - newCertNumbers.count
            errorMessage = "跳过 \(skipped) 个已存在的编号"
        }

        let semaphore = AsyncSemaphore(limit: 5)
        let batchTotalCount = Double(newCertNumbers.count)
        var results: [(Int, SubCardItem)] = []
        var errors: [String] = []

        await withTaskGroup(of: (Int, Result<SubCardItem, Error>).self) { group in
            for (idx, certNumber) in newCertNumbers.enumerated() {
                group.addTask {
                    await semaphore.wait()
                    defer { semaphore.signal() }
                    do {
                        let result = try await PSAService.shared.fetchCard(certNumber: certNumber)
                        let card = SubCardItem(
                            id: UUID(),
                            name: result.cardName,
                            set: result.cardSet,
                            number: result.cardNumber,
                            isPSA: true,
                            psaCertNumber: certNumber,
                            grade: result.grade,
                            population: result.population,
                            populationHigher: result.populationHigher,
                            psaImageFrontPath: result.frontImagePath,
                            psaImageBackPath: result.backImagePath,
                            localImagePath: nil,
                            year: result.year,
                            variety: result.variety,
                            gradeDescription: result.gradeDescription,
                            category: result.category,
                            labelType: result.labelType,
                            sortOrder: idx
                        )
                        return (idx, .success(card))
                    } catch {
                        return (idx, .failure(error))
                    }
                }
            }

            for await (idx, result) in group {
                batchProgress = Double(results.count + errors.count + 1) / batchTotalCount
                switch result {
                case .success(let card):
                    results.append((idx, card))
                case .failure:
                    errors.append(newCertNumbers[idx])
                }
            }
        }

        results.sort { $0.0 < $1.0 }
        for (_, card) in results {
            var mutableCard = card
            mutableCard.sortOrder = subcards.count
            subcards.append(mutableCard)
        }

        for i in subcards.indices {
            subcards[i].sortOrder = i
        }

        isBatchFetching = false
        batchProgress = 1.0
        showBatchAdd = false
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

final class AsyncSemaphore: @unchecked Sendable {
    private let limit: Int
    private let queue = DispatchQueue(label: "AsyncSemaphore", attributes: .concurrent)
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
        self.count = limit
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            queue.sync(flags: .barrier) {
                if count > 0 {
                    count -= 1
                    continuation.resume()
                } else {
                    waiters.append(continuation)
                }
            }
        }
    }

    func signal() {
        queue.sync(flags: .barrier) {
            if waiters.isEmpty {
                count += 1
            } else {
                let waiter = waiters.removeFirst()
                waiter.resume()
            }
        }
    }
}
