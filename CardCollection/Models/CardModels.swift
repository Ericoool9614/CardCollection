import Foundation

struct CardEntryItem: Identifiable, Hashable, Sendable {
    static func == (lhs: CardEntryItem, rhs: CardEntryItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    var nickname: String?
    var subcards: [SubCardItem]
    var purchaseDate: Date?
    var purchasePrice: Double?
    var sellDate: Date?
    var sellPrice: Double?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    var displayName: String {
        if let nick = nickname, !nick.isEmpty { return nick }
        if let first = subcards.first { return first.name }
        return "Untitled"
    }

    var isSold: Bool { sellDate != nil }

    var profit: Double? {
        guard let purchase = purchasePrice else { return nil }
        if let sell = sellPrice { return sell - purchase }
        return nil
    }

    var cardCount: Int { subcards.count }

    var hasPSA: Bool { subcards.contains { $0.isPSA } }

    var allPSA: Bool { subcards.allSatisfy { $0.isPSA } }

    var primaryCard: SubCardItem? { subcards.first }

    var frontImages: [String] {
        subcards.compactMap { card in
            guard let rawPath = card.psaImageFrontPath ?? card.localImagePath,
                  !rawPath.isEmpty else { return nil }
            let resolvedPath = ImageStorageService.resolvePath(rawPath)
            guard FileManager.default.fileExists(atPath: resolvedPath) else { return nil }
            return resolvedPath
        }
    }
}

struct SubCardItem: Identifiable, Hashable, Sendable {
    static func == (lhs: SubCardItem, rhs: SubCardItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    var name: String
    var set: String?
    var number: String?
    var isPSA: Bool
    var psaCertNumber: String?
    var grade: Int?
    var population: Int?
    var populationHigher: Int?
    var psaImageFrontPath: String?
    var psaImageBackPath: String?
    var localImagePath: String?
    var year: String?
    var variety: String?
    var gradeDescription: String?
    var category: String?
    var labelType: String?
    var sortOrder: Int

    var gradeDisplay: String {
        if isPSA, let desc = gradeDescription, !desc.isEmpty { return desc }
        if isPSA, let g = grade { return "PSA \(g)" }
        return "Raw"
    }

    var hasFrontImage: Bool {
        guard let path = psaImageFrontPath ?? localImagePath, !path.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: ImageStorageService.resolvePath(path))
    }

    var hasBackImage: Bool {
        guard let path = psaImageBackPath, !path.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: ImageStorageService.resolvePath(path))
    }

    var frontImagePath: String? {
        guard let rawPath = psaImageFrontPath ?? localImagePath, !rawPath.isEmpty else { return nil }
        let resolved = ImageStorageService.resolvePath(rawPath)
        return FileManager.default.fileExists(atPath: resolved) ? resolved : nil
    }
}
