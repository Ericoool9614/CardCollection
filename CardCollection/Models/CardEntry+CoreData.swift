import Foundation
import CoreData

@objc(CardEntry)
public class CardEntry: NSManagedObject {
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var nickname: String?
    @NSManaged public var note: String?
    @NSManaged public var purchaseDate: Date?
    @NSManaged public var purchasePrice: Double
    @NSManaged public var sellDate: Date?
    @NSManaged public var sellPrice: Double
    @NSManaged public var updatedAt: Date?
    @NSManaged public var subcards: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CardEntry> {
        return NSFetchRequest<CardEntry>(entityName: "CardEntry")
    }

    @objc(addSubcardsObject:)
    @NSManaged public func addToSubcards(_ value: SubCard)

    @objc(removeSubcardsObject:)
    @NSManaged public func removeFromSubcards(_ value: SubCard)

    @objc(addSubcards:)
    @NSManaged public func addToSubcards(_ values: NSSet)

    @objc(removeSubcards:)
    @NSManaged public func removeFromSubcards(_ values: NSSet)
}

@objc(SubCard)
public class SubCard: NSManagedObject {
    @NSManaged public var category: String?
    @NSManaged public var grade: Int32
    @NSManaged public var gradeDescription: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isPSA: Bool
    @NSManaged public var labelType: String?
    @NSManaged public var localImagePath: String?
    @NSManaged public var name: String?
    @NSManaged public var number: String?
    @NSManaged public var population: Int32
    @NSManaged public var populationHigher: Int32
    @NSManaged public var psaCertNumber: String?
    @NSManaged public var psaImageBackPath: String?
    @NSManaged public var psaImageFrontPath: String?
    @NSManaged public var set: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var variety: String?
    @NSManaged public var year: String?
    @NSManaged public var entry: CardEntry?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubCard> {
        return NSFetchRequest<SubCard>(entityName: "SubCard")
    }
}

extension CardEntry {
    var displayName: String {
        if let nick = nickname, !nick.isEmpty { return nick }
        if let firstCard = subcardsSorted.first { return firstCard.name ?? "Untitled" }
        return "Untitled"
    }

    var isSold: Bool { sellDate != nil }

    var profit: Double? {
        guard purchasePrice > 0 else { return nil }
        if sellDate != nil { return sellPrice - purchasePrice }
        return nil
    }

    var subcardsSorted: [SubCard] {
        (subcards as? Set<SubCard>)?
            .sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    var cardCount: Int { subcards?.count ?? 0 }

    var hasPSA: Bool { subcardsSorted.contains { $0.isPSA } }

    func toItem() -> CardEntryItem {
        let sortedSubs = subcardsSorted
        return CardEntryItem(
            id: id ?? UUID(),
            nickname: nickname,
            subcards: sortedSubs.map { $0.toItem() },
            purchaseDate: purchaseDate,
            purchasePrice: purchasePrice > 0 ? purchasePrice : nil,
            sellDate: sellDate,
            sellPrice: sellPrice > 0 ? sellPrice : nil,
            note: note,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    func updateFromItem(_ item: CardEntryItem) {
        id = item.id
        nickname = item.nickname
        purchaseDate = item.purchaseDate
        purchasePrice = item.purchasePrice ?? 0
        sellDate = item.sellDate
        sellPrice = item.sellPrice ?? 0
        note = item.note
        updatedAt = Date()
    }
}

extension SubCard {
    var gradeDisplay: String {
        if isPSA, let desc = gradeDescription, !desc.isEmpty { return desc }
        if isPSA, grade > 0 { return "PSA \(grade)" }
        return "Raw"
    }

    var hasFrontImage: Bool {
        let path = psaImageFrontPath ?? localImagePath
        guard let p = path, !p.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: ImageStorageService.resolvePath(p))
    }

    var hasBackImage: Bool {
        guard let p = psaImageBackPath, !p.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: ImageStorageService.resolvePath(p))
    }

    var frontImagePath: String? {
        guard let p = psaImageFrontPath ?? localImagePath, !p.isEmpty else { return nil }
        let resolved = ImageStorageService.resolvePath(p)
        return FileManager.default.fileExists(atPath: resolved) ? resolved : nil
    }

    func toItem() -> SubCardItem {
        SubCardItem(
            id: id ?? UUID(),
            name: name ?? "",
            set: set,
            number: number,
            isPSA: isPSA,
            psaCertNumber: psaCertNumber,
            grade: grade > 0 ? Int(grade) : nil,
            population: population > 0 ? Int(population) : nil,
            populationHigher: populationHigher > 0 ? Int(populationHigher) : nil,
            psaImageFrontPath: psaImageFrontPath,
            psaImageBackPath: psaImageBackPath,
            localImagePath: localImagePath,
            year: year,
            variety: variety,
            gradeDescription: gradeDescription,
            category: category,
            labelType: labelType,
            sortOrder: Int(sortOrder)
        )
    }

    func updateFromItem(_ item: SubCardItem) {
        id = item.id
        name = item.name
        set = item.set
        number = item.number
        isPSA = item.isPSA
        psaCertNumber = item.psaCertNumber
        grade = item.grade.map { Int32($0) } ?? 0
        population = item.population.map { Int32($0) } ?? 0
        populationHigher = item.populationHigher.map { Int32($0) } ?? 0
        psaImageFrontPath = item.psaImageFrontPath
        psaImageBackPath = item.psaImageBackPath
        localImagePath = item.localImagePath
        year = item.year
        variety = item.variety
        gradeDescription = item.gradeDescription
        category = item.category
        labelType = item.labelType
        sortOrder = Int32(item.sortOrder)
    }
}
