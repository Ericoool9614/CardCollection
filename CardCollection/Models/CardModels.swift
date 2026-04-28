import Foundation
import SwiftUI

enum GradingCompany: String, CaseIterable, Sendable {
    case psa = "PSA"
    case ccic = "CCIC"
    case bgs = "BGS"
    case other = "其他"

    static let `default` = GradingCompany.psa

    var gradeOptions: [String] {
        switch self {
        case .psa: return ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        case .ccic: return ["银10", "金10"]
        case .bgs: return ["9.5", "10", "黑10"]
        case .other: return []
        }
    }

    var isFreeTextInput: Bool { self == .other }

    var displayColor: SwiftUI.Color {
        switch self {
        case .psa: return .orange
        case .ccic: return .red
        case .bgs: return .blue
        case .other: return .gray
        }
    }
}

enum CardLanguage: String, CaseIterable, Sendable {
    case japanese = "日版"
    case english = "美版"
    case simplifiedChinese = "简中"
    case traditionalChinese = "繁中"
    case other = "其他"

    static let `default` = CardLanguage.japanese
}

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
    var askingPrice: Double?
    var language: String = CardLanguage.default.rawValue

    var displayName: String {
        if let nick = nickname, !nick.isEmpty { return nick }
        if let first = subcards.first { return first.name }
        return "未命名"
    }

    var isSold: Bool { sellDate != nil }

    var profit: Double? {
        guard let purchase = purchasePrice else { return nil }
        if let sell = sellPrice { return sell - purchase }
        return nil
    }

    var profitDisplay: String? {
        guard let profit = profit else { return nil }
        let sign = profit >= 0 ? "+" : "-"
        return "\(sign)¥\(String(format: "%.2f", abs(profit)))"
    }

    var cardCount: Int { subcards.count }

    var hasPSA: Bool { subcards.contains { $0.isPSA } }

    var allPSA: Bool { subcards.allSatisfy { $0.isPSA } }

    var primaryCard: SubCardItem? { subcards.first }

    var maxPopulation: Int? {
        let pops = subcards.compactMap { $0.population }
        return pops.isEmpty ? nil : pops.max()
    }

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
    var grade: String?
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
    var gradingCompany: String = GradingCompany.default.rawValue

    var gradeDisplay: String {
        if isPSA, let desc = gradeDescription, !desc.isEmpty { return desc }
        if isPSA, let g = grade { return "\(gradingCompanyEnum.rawValue) \(g)" }
        return "裸卡"
    }

    var gradingCompanyEnum: GradingCompany {
        let raw = gradingCompany.isEmpty ? GradingCompany.default.rawValue : gradingCompany
        return GradingCompany(rawValue: raw) ?? .default
    }

    var gradeInt: Int? {
        guard let g = grade else { return nil }
        return Int(g)
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

    var allImagePaths: [String] {
        var paths: [String] = []
        if let frontPath = psaImageFrontPath, !frontPath.isEmpty {
            let resolved = ImageStorageService.resolvePath(frontPath)
            if FileManager.default.fileExists(atPath: resolved) { paths.append(resolved) }
        }
        if let backPath = psaImageBackPath, !backPath.isEmpty {
            let resolved = ImageStorageService.resolvePath(backPath)
            if FileManager.default.fileExists(atPath: resolved) { paths.append(resolved) }
        }
        if !isPSA, let localPath = localImagePath, !localPath.isEmpty {
            let resolved = ImageStorageService.resolvePath(localPath)
            if FileManager.default.fileExists(atPath: resolved) { paths.append(resolved) }
        }
        return paths
    }
}
