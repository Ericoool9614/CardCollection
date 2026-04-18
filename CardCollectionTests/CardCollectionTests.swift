import XCTest
import CoreData
@testable import CardCollection

@MainActor
final class CardCollectionTests: XCTestCase {

    private var persistence: PersistenceController!

    override func setUp() async throws {
        persistence = PersistenceController(inMemory: true)
    }

    override func tearDown() async throws {
        persistence = nil
    }

    func testCreateEntrySavesSubcards() async throws {
        let subcardItem = SubCardItem(
            id: UUID(),
            name: "PIKACHU",
            set: "POKEMON JAPANESE M-P PROMO",
            number: "020",
            isPSA: true,
            psaCertNumber: "133880310",
            grade: 10,
            population: 258889,
            populationHigher: 0,
            psaImageFrontPath: "PSAImages/PSA_133880310_front.jpg",
            psaImageBackPath: "PSAImages/PSA_133880310_back.jpg",
            localImagePath: nil,
            year: "2025",
            variety: "McDONALD'S",
            gradeDescription: "GEM MT 10",
            category: "TCG Cards",
            labelType: "LighthouseLabel",
            sortOrder: 0
        )

        let entryItem = CardEntryItem(
            id: UUID(),
            nickname: "My Pikachu",
            subcards: [subcardItem],
            purchaseDate: Date(),
            purchasePrice: 100.0,
            sellDate: nil,
            sellPrice: nil,
            note: "Test note",
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)

        XCTAssertEqual(entry.nickname, "My Pikachu")
        XCTAssertEqual(entry.purchasePrice, 100.0)
        XCTAssertEqual(entry.note, "Test note")

        let subcards = entry.subcardsSorted
        XCTAssertEqual(subcards.count, 1, "Should have 1 subcard")

        if let sub = subcards.first {
            XCTAssertEqual(sub.name, "PIKACHU")
            XCTAssertEqual(sub.set, "POKEMON JAPANESE M-P PROMO")
            XCTAssertEqual(sub.isPSA, true)
            XCTAssertEqual(sub.psaCertNumber, "133880310")
            XCTAssertEqual(sub.grade, 10)
            XCTAssertEqual(sub.gradeDescription, "GEM MT 10")
        }

        let fetched = persistence.fetchAllEntries()
        XCTAssertEqual(fetched.count, 1)

        if let fetchedEntry = fetched.first {
            let item = fetchedEntry.toItem()
            XCTAssertEqual(item.nickname, "My Pikachu")
            XCTAssertEqual(item.subcards.count, 1)
            XCTAssertEqual(item.subcards.first?.name, "PIKACHU")
        }
    }

    func testPSAServiceFetchAndSave() async throws {
        let result: PSACardResult
        do {
            result = try await PSAService.shared.fetchCard(certNumber: "133880310")
        } catch PSAServiceError.rateLimitExceeded {
            throw XCTSkip("API请求频率超限，跳过测试")
        } catch PSAServiceError.quotaExhausted {
            throw XCTSkip("API每日额度已用完，跳过测试")
        }

        XCTAssertEqual(result.cardName, "PIKACHU")
        XCTAssertEqual(result.cardSet, "POKEMON JAPANESE M-P PROMO")
        XCTAssertEqual(result.grade, 10)
        XCTAssertEqual(result.gradeDescription, "GEM MT 10")

        let subcardItem = SubCardItem(
            id: UUID(),
            name: result.cardName,
            set: result.cardSet,
            number: result.cardNumber,
            isPSA: true,
            psaCertNumber: "133880310",
            grade: result.grade,
            population: result.population,
            populationHigher: result.populationHigher,
            psaImageFrontPath: result.frontImagePath,
            psaImageBackPath: result.backImagePath,
            year: result.year,
            variety: result.variety,
            gradeDescription: result.gradeDescription,
            category: result.category,
            labelType: result.labelType,
            sortOrder: 0
        )

        let entryItem = CardEntryItem(
            id: UUID(),
            nickname: nil,
            subcards: [subcardItem],
            purchaseDate: nil,
            purchasePrice: nil,
            sellDate: nil,
            sellPrice: nil,
            note: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)
        let subcards = entry.subcardsSorted
        XCTAssertEqual(subcards.count, 1)
        XCTAssertEqual(subcards.first?.name, "PIKACHU")
        XCTAssertEqual(subcards.first?.isPSA, true)
        XCTAssertEqual(subcards.first?.grade, 10)
    }

    func testMultipleSubcardsInEntry() async throws {
        let sub1 = SubCardItem(
            id: UUID(), name: "PIKACHU", set: "POKEMON JAPANESE M-P PROMO",
            number: "020", isPSA: true, psaCertNumber: "133880310",
            grade: 10, population: 258889, populationHigher: 0,
            psaImageFrontPath: "PSAImages/PSA_133880310_front.jpg",
            psaImageBackPath: "PSAImages/PSA_133880310_back.jpg",
            localImagePath: nil, year: "2025", variety: "McDONALD'S",
            gradeDescription: "GEM MT 10", category: "TCG Cards",
            labelType: "LighthouseLabel", sortOrder: 0
        )

        let sub2 = SubCardItem(
            id: UUID(), name: "CHARIZARD", set: "POKEMON BASE SET",
            number: "004", isPSA: true, psaCertNumber: "999999999",
            grade: 9, population: 1000, populationHigher: 50,
            psaImageFrontPath: "PSAImages/PSA_999999999_front.jpg",
            psaImageBackPath: "PSAImages/PSA_999999999_back.jpg",
            localImagePath: nil, year: "1999", variety: nil,
            gradeDescription: "MINT 9", category: "TCG Cards",
            labelType: "StandardLabel", sortOrder: 1
        )

        let entryItem = CardEntryItem(
            id: UUID(), nickname: "My Collection", subcards: [sub1, sub2],
            purchaseDate: Date(), purchasePrice: 500.0,
            sellDate: nil, sellPrice: nil, note: "Two cards",
            createdAt: Date(), updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)
        let subcards = entry.subcardsSorted
        XCTAssertEqual(subcards.count, 2)
        XCTAssertEqual(subcards[0].name, "PIKACHU")
        XCTAssertEqual(subcards[1].name, "CHARIZARD")

        let item = entry.toItem()
        XCTAssertEqual(item.cardCount, 2)
        XCTAssertEqual(item.primaryCard?.name, "PIKACHU")
    }

    func testThumbnailUsesFirstCardImage() async throws {
        let sub1 = SubCardItem(
            id: UUID(), name: "PIKACHU", set: "SET1", number: "020",
            isPSA: true, psaCertNumber: "133880310", grade: 10,
            population: 258889, populationHigher: 0,
            psaImageFrontPath: "PSAImages/PSA_133880310_front.jpg",
            psaImageBackPath: "PSAImages/PSA_133880310_back.jpg",
            localImagePath: nil, year: "2025", variety: nil,
            gradeDescription: "GEM MT 10", category: "TCG Cards",
            labelType: "LighthouseLabel", sortOrder: 0
        )

        let sub2 = SubCardItem(
            id: UUID(), name: "CHARIZARD", set: "SET2", number: "004",
            isPSA: true, psaCertNumber: "999999999", grade: 9,
            population: 1000, populationHigher: 50,
            psaImageFrontPath: "PSAImages/PSA_999999999_front.jpg",
            psaImageBackPath: "PSAImages/PSA_999999999_back.jpg",
            localImagePath: nil, year: "1999", variety: nil,
            gradeDescription: "MINT 9", category: "TCG Cards",
            labelType: "StandardLabel", sortOrder: 1
        )

        let entryItem = CardEntryItem(
            id: UUID(), nickname: "My Collection", subcards: [sub1, sub2],
            purchaseDate: Date(), purchasePrice: 500.0,
            sellDate: nil, sellPrice: nil, note: nil,
            createdAt: Date(), updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)
        let item = entry.toItem()

        XCTAssertEqual(item.primaryCard?.name, "PIKACHU")
        XCTAssertEqual(item.primaryCard?.psaImageFrontPath, "PSAImages/PSA_133880310_front.jpg")
    }

    func testRawCardThumbnailUsesLocalImage() async throws {
        let sub1 = SubCardItem(
            id: UUID(), name: "My Raw Card", set: "SOME SET", number: "001",
            isPSA: false, psaCertNumber: nil, grade: nil,
            population: nil, populationHigher: nil,
            psaImageFrontPath: nil, psaImageBackPath: nil,
            localImagePath: "LocalImages/Local_test.jpg",
            year: nil, variety: nil, gradeDescription: nil,
            category: nil, labelType: nil, sortOrder: 0
        )

        let entryItem = CardEntryItem(
            id: UUID(), nickname: "Raw Card Entry", subcards: [sub1],
            purchaseDate: Date(), purchasePrice: 50.0,
            sellDate: nil, sellPrice: nil, note: nil,
            createdAt: Date(), updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)
        let item = entry.toItem()

        let firstCardImagePath = item.subcards.first?.psaImageFrontPath ?? item.subcards.first?.localImagePath
        XCTAssertEqual(firstCardImagePath, "LocalImages/Local_test.jpg")
        XCTAssertEqual(item.subcards.first?.isPSA, false)
    }

    // MARK: - Feature 1: Image Download

    func testSubCardAllImagePathsPSA() async throws {
        let docsDir = ImageStorageService.documentsDirectory
        let frontResolved = docsDir.appendingPathComponent("PSAImages/PSA_133880310_front.jpg").path
        let backResolved = docsDir.appendingPathComponent("PSAImages/PSA_133880310_back.jpg").path
        try? FileManager.default.createDirectory(at: docsDir.appendingPathComponent("PSAImages"), withIntermediateDirectories: true)
        let data = UIImage(systemName: "star")!.jpegData(compressionQuality: 0.5)!
        try data.write(to: URL(fileURLWithPath: frontResolved))
        try data.write(to: URL(fileURLWithPath: backResolved))

        let sub = SubCardItem(
            id: UUID(), name: "PIKACHU", set: "SET1", number: "020",
            isPSA: true, psaCertNumber: "133880310", grade: 10,
            population: 258889, populationHigher: 0,
            psaImageFrontPath: "PSAImages/PSA_133880310_front.jpg",
            psaImageBackPath: "PSAImages/PSA_133880310_back.jpg",
            localImagePath: nil, year: "2025", variety: nil,
            gradeDescription: "GEM MT 10", category: "TCG Cards",
            labelType: "LighthouseLabel", sortOrder: 0
        )

        let paths = sub.allImagePaths
        XCTAssertEqual(paths.count, 2, "PSA card should have front and back image paths")

        try? FileManager.default.removeItem(atPath: frontResolved)
        try? FileManager.default.removeItem(atPath: backResolved)
    }

    func testSubCardAllImagePathsRaw() async throws {
        let docsDir = ImageStorageService.documentsDirectory
        let localResolved = docsDir.appendingPathComponent("LocalImages/Local_test.jpg").path
        try? FileManager.default.createDirectory(at: docsDir.appendingPathComponent("LocalImages"), withIntermediateDirectories: true)
        let data = UIImage(systemName: "star")!.jpegData(compressionQuality: 0.5)!
        try data.write(to: URL(fileURLWithPath: localResolved))

        let sub = SubCardItem(
            id: UUID(), name: "My Raw Card", set: "SET", number: "001",
            isPSA: false, psaCertNumber: nil, grade: nil,
            population: nil, populationHigher: nil,
            psaImageFrontPath: nil, psaImageBackPath: nil,
            localImagePath: "LocalImages/Local_test.jpg",
            year: nil, variety: nil, gradeDescription: nil,
            category: nil, labelType: nil, sortOrder: 0
        )

        let paths = sub.allImagePaths
        XCTAssertEqual(paths.count, 1, "Raw card should have 1 local image path")

        try? FileManager.default.removeItem(atPath: localResolved)
    }

    // MARK: - Feature 2: Sorting

    func testSortByPurchasePrice() async throws {
        let entry1 = CardEntryItem(
            id: UUID(), nickname: "Cheap", subcards: [SubCardItem(
                id: UUID(), name: "Card1", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 100.0, createdAt: Date(), updatedAt: Date()
        )

        let entry2 = CardEntryItem(
            id: UUID(), nickname: "Expensive", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 500.0, createdAt: Date(), updatedAt: Date()
        )

        _ = persistence.createEntry(from: entry1)
        _ = persistence.createEntry(from: entry2)

        let items = persistence.fetchAllEntries().map { $0.toItem() }
        let sortedDesc = items.sorted { ($0.purchasePrice ?? 0) > ($1.purchasePrice ?? 0) }
        XCTAssertEqual(sortedDesc.first?.nickname, "Expensive")

        let sortedAsc = items.sorted { ($0.purchasePrice ?? 0) < ($1.purchasePrice ?? 0) }
        XCTAssertEqual(sortedAsc.first?.nickname, "Cheap")
    }

    func testSortByPopulation() async throws {
        let entry1 = CardEntryItem(
            id: UUID(), nickname: "Low Pop", subcards: [SubCardItem(
                id: UUID(), name: "Card1", isPSA: true, population: 100, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date()
        )

        let entry2 = CardEntryItem(
            id: UUID(), nickname: "High Pop", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: true, population: 258889, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date()
        )

        _ = persistence.createEntry(from: entry1)
        _ = persistence.createEntry(from: entry2)

        let items = persistence.fetchAllEntries().map { $0.toItem() }
        let sorted = items.sorted { ($0.maxPopulation ?? 0) > ($1.maxPopulation ?? 0) }
        XCTAssertEqual(sorted.first?.nickname, "High Pop")
    }

    // MARK: - Feature 3: Filtering

    func testFilterBySoldStatus() async throws {
        let entry1 = CardEntryItem(
            id: UUID(), nickname: "Unsold", subcards: [SubCardItem(
                id: UUID(), name: "Card1", isPSA: true, sortOrder: 0
            )],
            sellDate: nil, createdAt: Date(), updatedAt: Date()
        )

        let entry2 = CardEntryItem(
            id: UUID(), nickname: "Sold", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: true, sortOrder: 0
            )],
            sellDate: Date(), sellPrice: 200.0, createdAt: Date(), updatedAt: Date()
        )

        _ = persistence.createEntry(from: entry1)
        _ = persistence.createEntry(from: entry2)

        let items = persistence.fetchAllEntries().map { $0.toItem() }
        let unsold = items.filter { !$0.isSold }
        let sold = items.filter { $0.isSold }

        XCTAssertEqual(unsold.count, 1)
        XCTAssertEqual(sold.count, 1)
        XCTAssertEqual(unsold.first?.nickname, "Unsold")
        XCTAssertEqual(sold.first?.nickname, "Sold")
    }

    func testFilterByPSAStatus() async throws {
        let entry1 = CardEntryItem(
            id: UUID(), nickname: "PSA Entry", subcards: [SubCardItem(
                id: UUID(), name: "Card1", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date()
        )

        let entry2 = CardEntryItem(
            id: UUID(), nickname: "Raw Entry", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: false, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date()
        )

        _ = persistence.createEntry(from: entry1)
        _ = persistence.createEntry(from: entry2)

        let items = persistence.fetchAllEntries().map { $0.toItem() }
        let psa = items.filter { $0.hasPSA }
        let raw = items.filter { !$0.hasPSA }

        XCTAssertEqual(psa.count, 1)
        XCTAssertEqual(raw.count, 1)
        XCTAssertEqual(psa.first?.nickname, "PSA Entry")
        XCTAssertEqual(raw.first?.nickname, "Raw Entry")
    }

    // MARK: - Feature 4: Chinese & RMB

    func testGradeDisplayInChinese() async throws {
        let psaCard = SubCardItem(
            id: UUID(), name: "Test", isPSA: true,
            grade: 10, gradeDescription: "GEM MT 10", sortOrder: 0
        )
        XCTAssertEqual(psaCard.gradeDisplay, "GEM MT 10")

        let rawCard = SubCardItem(
            id: UUID(), name: "Test", isPSA: false, sortOrder: 0
        )
        XCTAssertEqual(rawCard.gradeDisplay, "裸卡")
    }

    func testDisplayNameInChinese() async throws {
        let entry = CardEntryItem(
            id: UUID(), nickname: nil, subcards: [SubCardItem(
                id: UUID(), name: "PIKACHU", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertEqual(entry.displayName, "PIKACHU")

        let emptyEntry = CardEntryItem(
            id: UUID(), nickname: nil, subcards: [],
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertEqual(emptyEntry.displayName, "未命名")
    }

    func testRMBProfitCalculation() async throws {
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 100.0, sellDate: Date(),
            sellPrice: 150.0, createdAt: Date(), updatedAt: Date()
        )

        XCTAssertEqual(entry.profit, 50.0)
        XCTAssertEqual(entry.isSold, true)
    }

    // MARK: - Bug Fixes

    func testAskingPriceSavedAndLoaded() async throws {
        let entryItem = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 100.0, sellDate: nil, sellPrice: nil,
            note: nil, createdAt: Date(), updatedAt: Date(), askingPrice: 200.0
        )

        let entry = persistence.createEntry(from: entryItem)
        XCTAssertEqual(entry.askingPrice, 200.0)

        let fetched = persistence.fetchAllEntries()
        let item = fetched.first!.toItem()
        XCTAssertEqual(item.askingPrice, 200.0)
    }

    func testMultipleSubcardsInPSAEntry() async throws {
        let sub1 = SubCardItem(
            id: UUID(), name: "PIKACHU", isPSA: true,
            psaCertNumber: "133880310", grade: 10,
            gradeDescription: "GEM MT 10", sortOrder: 0
        )
        let sub2 = SubCardItem(
            id: UUID(), name: "CHARIZARD", isPSA: true,
            psaCertNumber: "133880311", grade: 9,
            gradeDescription: "MINT 9", sortOrder: 1
        )

        let entryItem = CardEntryItem(
            id: UUID(), nickname: "Multi PSA", subcards: [sub1, sub2],
            createdAt: Date(), updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)
        let subcards = entry.subcardsSorted
        XCTAssertEqual(subcards.count, 2)
        XCTAssertEqual(subcards[0].name, "PIKACHU")
        XCTAssertEqual(subcards[1].name, "CHARIZARD")
        XCTAssertEqual(subcards[0].grade, 10)
        XCTAssertEqual(subcards[1].grade, 9)
    }

    // MARK: - CSV Export/Import

    func testCSVExportWithImagePaths() async throws {
        let sub = SubCardItem(
            id: UUID(), name: "PIKACHU", set: "SET1", number: "020",
            isPSA: true, psaCertNumber: "133880310", grade: 10,
            psaImageFrontPath: "PSAImages/PSA_133880310_front.jpg",
            psaImageBackPath: "PSAImages/PSA_133880310_back.jpg",
            gradeDescription: "GEM MT 10", sortOrder: 0
        )

        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [sub],
            purchasePrice: 100.0, createdAt: Date(), updatedAt: Date()
        )

        let url = CSVExportService.export(entries: [entry])
        XCTAssertNotNil(url)

        let content = try! String(contentsOf: url!, encoding: .utf8)
        XCTAssertTrue(content.contains("PSAImages/PSA_133880310_front.jpg"))
        XCTAssertTrue(content.contains("PSAImages/PSA_133880310_back.jpg"))
        XCTAssertTrue(content.contains("正面图片路径"))
        XCTAssertTrue(content.contains("背面图片路径"))
    }

    func testCSVImportService() async throws {
        let csvContent = "昵称,卡名,系列,编号,是否评级,评级,Pop,年份,变体,购买日期,购买价格(¥),出售日期,出售价格(¥),盈亏(¥),备注,正面图片路径,背面图片路径\nTest,PIKACHU,SET1,020,是,GEM MT 10,100,2025,,2025-01-01,100.00,,,,,,,\n"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_import.csv")
        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)

        let entries = CSVImportService.importFrom(url: tempURL)
        XCTAssertNotNil(entries)
        XCTAssertEqual(entries?.count, 1)
        XCTAssertEqual(entries?.first?.nickname, "Test")
        XCTAssertEqual(entries?.first?.subcards.first?.name, "PIKACHU")
        XCTAssertEqual(entries?.first?.subcards.first?.isPSA, true)
        XCTAssertEqual(entries?.first?.subcards.first?.gradeDescription, "GEM MT 10")

        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Profit Display

    func testProfitDisplayPositive() async throws {
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 100.0, sellDate: Date(), sellPrice: 200.0,
            note: nil, createdAt: Date(), updatedAt: Date()
        )
        XCTAssertEqual(entry.profitDisplay, "+¥100.00")
    }

    func testProfitDisplayNegative() async throws {
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 200.0, sellDate: Date(), sellPrice: 100.0,
            note: nil, createdAt: Date(), updatedAt: Date()
        )
        XCTAssertEqual(entry.profitDisplay, "-¥100.00")
    }

    func testProfitDisplayNil() async throws {
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertNil(entry.profitDisplay)
    }

    // MARK: - Duplicate PSA Card Check

    func testDuplicatePSACardDetection() async throws {
        let existingSub = SubCardItem(
            id: UUID(), name: "PIKACHU", isPSA: true,
            psaCertNumber: "133880310", grade: 10,
            gradeDescription: "GEM MT 10", sortOrder: 0
        )
        let existingEntry = CardEntryItem(
            id: UUID(), nickname: "Existing", subcards: [existingSub],
            purchasePrice: 100.0, createdAt: Date(), updatedAt: Date()
        )
        _ = persistence.createEntry(from: existingEntry)

        let allEntries = persistence.fetchAllEntries()
        let allCertNumbers = allEntries.flatMap { $0.subcardsSorted }
            .compactMap { $0.psaCertNumber }
        XCTAssertTrue(allCertNumbers.contains("133880310"), "Should find existing cert number")
    }

    // MARK: - Sold Entry No Purchase Price in CardInfo

    func testSoldEntryProfitDisplayInGrid() async throws {
        let entry = CardEntryItem(
            id: UUID(), nickname: "Sold Card", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 200.0, sellDate: Date(), sellPrice: 300.0,
            note: nil, createdAt: Date(), updatedAt: Date()
        )

        XCTAssertTrue(entry.isSold)
        XCTAssertEqual(entry.profit, 100.0)
        XCTAssertEqual(entry.profitDisplay, "+¥100.00")
    }

    // MARK: - Search by PSA Cert Number

    func testSearchByPSACertNumber() async throws {
        let sub1 = SubCardItem(
            id: UUID(), name: "PIKACHU", isPSA: true,
            psaCertNumber: "133880310", grade: 10,
            gradeDescription: "GEM MT 10", sortOrder: 0
        )
        let sub2 = SubCardItem(
            id: UUID(), name: "CHARIZARD", isPSA: true,
            psaCertNumber: "999888777", grade: 9,
            gradeDescription: "MINT 9", sortOrder: 0
        )

        let entry1 = CardEntryItem(
            id: UUID(), nickname: "Entry1", subcards: [sub1],
            createdAt: Date(), updatedAt: Date()
        )
        let entry2 = CardEntryItem(
            id: UUID(), nickname: "Entry2", subcards: [sub2],
            createdAt: Date(), updatedAt: Date()
        )

        let items = [entry1, entry2]

        let filtered = items.filter { entry in
            entry.nickname?.localizedCaseInsensitiveContains("133880310") ?? false ||
            entry.subcards.contains {
                $0.name.localizedCaseInsensitiveContains("133880310") ||
                ($0.set?.localizedCaseInsensitiveContains("133880310") ?? false) ||
                ($0.number?.localizedCaseInsensitiveContains("133880310") ?? false) ||
                ($0.psaCertNumber?.localizedCaseInsensitiveContains("133880310") ?? false)
            }
        }

        XCTAssertEqual(filtered.count, 1, "Should find entry by PSA cert number")
        XCTAssertEqual(filtered.first?.subcards.first?.psaCertNumber, "133880310")
    }
}
