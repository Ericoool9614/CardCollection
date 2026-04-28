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
            grade: "10",
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
            XCTAssertEqual(sub.grade, "10")
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
        XCTAssertEqual(result.grade, "10")
        XCTAssertEqual(result.gradeDescription, "GEM MT 10")

        let subcardItem = SubCardItem(
            id: UUID(),
            name: result.cardName,
            set: result.cardSet,
            number: result.cardNumber,
            isPSA: true,
            psaCertNumber: "133880310",
            grade: result.grade.isEmpty ? nil : result.grade,
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
        XCTAssertEqual(subcards.first?.grade, "10")
    }

    func testMultipleSubcardsInEntry() async throws {
        let sub1 = SubCardItem(
            id: UUID(), name: "PIKACHU", set: "POKEMON JAPANESE M-P PROMO",
            number: "020", isPSA: true, psaCertNumber: "133880310",
            grade: "10", population: 258889, populationHigher: 0,
            psaImageFrontPath: "PSAImages/PSA_133880310_front.jpg",
            psaImageBackPath: "PSAImages/PSA_133880310_back.jpg",
            localImagePath: nil, year: "2025", variety: "McDONALD'S",
            gradeDescription: "GEM MT 10", category: "TCG Cards",
            labelType: "LighthouseLabel", sortOrder: 0
        )

        let sub2 = SubCardItem(
            id: UUID(), name: "CHARIZARD", set: "POKEMON BASE SET",
            number: "004", isPSA: true, psaCertNumber: "999999999",
            grade: "9", population: 1000, populationHigher: 50,
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
            isPSA: true, psaCertNumber: "133880310", grade: "10",
            population: 258889, populationHigher: 0,
            psaImageFrontPath: "PSAImages/PSA_133880310_front.jpg",
            psaImageBackPath: "PSAImages/PSA_133880310_back.jpg",
            localImagePath: nil, year: "2025", variety: nil,
            gradeDescription: "GEM MT 10", category: "TCG Cards",
            labelType: "LighthouseLabel", sortOrder: 0
        )

        let sub2 = SubCardItem(
            id: UUID(), name: "CHARIZARD", set: "SET2", number: "004",
            isPSA: true, psaCertNumber: "999999999", grade: "9",
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
            isPSA: true, psaCertNumber: "133880310", grade: "10",
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
                id: UUID(), name: "Card1", isPSA: true, grade: "10", sortOrder: 0
            )],
            purchasePrice: 100.0, createdAt: Date(), updatedAt: Date()
        )

        let entry2 = CardEntryItem(
            id: UUID(), nickname: "Expensive", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: true, grade: "9", sortOrder: 0
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
                id: UUID(), name: "Card1", isPSA: true, grade: "10", population: 100, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date()
        )

        let entry2 = CardEntryItem(
            id: UUID(), nickname: "High Pop", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: true, grade: "9", population: 258889, sortOrder: 0
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
                id: UUID(), name: "Card1", isPSA: true, grade: "10", sortOrder: 0
            )],
            sellDate: nil, createdAt: Date(), updatedAt: Date()
        )

        let entry2 = CardEntryItem(
            id: UUID(), nickname: "Sold", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: true, grade: "9", sortOrder: 0
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
            grade: "10", gradeDescription: "GEM MT 10", sortOrder: 0
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
            psaCertNumber: "133880310", grade: "10",
            gradeDescription: "GEM MT 10", sortOrder: 0
        )
        let sub2 = SubCardItem(
            id: UUID(), name: "CHARIZARD", isPSA: true,
            psaCertNumber: "133880311", grade: "9",
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
        XCTAssertEqual(subcards[0].grade, "10")
        XCTAssertEqual(subcards[1].grade, "9")
    }

    // MARK: - CSV Export/Import

    func testCSVExportWithImagePaths() async throws {
        let sub = SubCardItem(
            id: UUID(), name: "PIKACHU", set: "SET1", number: "020",
            isPSA: true, psaCertNumber: "133880310", grade: "10",
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
        let csvContent = "昵称,卡名,系列,编号,是否评级,评级公司,评级分数,评级描述,Pop,年份,变体,购买日期,购买价格(¥),出售日期,出售价格(¥),盈亏(¥),备注,正面图片路径,背面图片路径\nTest,PIKACHU,SET1,020,是,PSA,10,GEM MT 10,100,2025,,2025-01-01,100.00,,,,,,,\n"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_import.csv")
        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)

        let entries = CSVImportService.importFrom(url: tempURL)
        XCTAssertNotNil(entries)
        XCTAssertEqual(entries?.count, 1)
        XCTAssertEqual(entries?.first?.nickname, "Test")
        XCTAssertEqual(entries?.first?.subcards.first?.name, "PIKACHU")
        XCTAssertEqual(entries?.first?.subcards.first?.isPSA, true)
        XCTAssertEqual(entries?.first?.subcards.first?.grade, "10")
        XCTAssertEqual(entries?.first?.subcards.first?.gradeDescription, "GEM MT 10")
        XCTAssertEqual(entries?.first?.subcards.first?.gradingCompany, "PSA")

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
            psaCertNumber: "133880310", grade: "10",
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
            psaCertNumber: "133880310", grade: "10",
            gradeDescription: "GEM MT 10", sortOrder: 0
        )
        let sub2 = SubCardItem(
            id: UUID(), name: "CHARIZARD", isPSA: true,
            psaCertNumber: "999888777", grade: "9",
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

    // MARK: - Feature 1: PSA Card Manual Entry

    func testCanSaveWithGradeAndName() async throws {
        let card = SubCardItem(
            id: UUID(), name: "PIKACHU", isPSA: true,
            grade: "10", gradeDescription: "PSA 10", sortOrder: 0
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertFalse(entry.subcards.first!.name.isEmpty)
        XCTAssertNotNil(entry.subcards.first!.grade)
    }

    func testCanSaveRequiresGrade() async throws {
        let card = SubCardItem(
            id: UUID(), name: "PIKACHU", isPSA: true, sortOrder: 0
        )
        let canSave = !card.name.isEmpty && card.grade != nil
        XCTAssertFalse(canSave, "Should not be able to save without grade")
    }

    // MARK: - Feature 2: Language Version

    func testCardLanguageDefault() async throws {
        XCTAssertEqual(CardLanguage.default, .japanese)
        XCTAssertEqual(CardLanguage.default.rawValue, "日版")
    }

    func testCardLanguageAllCases() async throws {
        XCTAssertEqual(CardLanguage.allCases.count, 5)
        let rawValues = CardLanguage.allCases.map { $0.rawValue }
        XCTAssertTrue(rawValues.contains("日版"))
        XCTAssertTrue(rawValues.contains("美版"))
        XCTAssertTrue(rawValues.contains("简中"))
        XCTAssertTrue(rawValues.contains("繁中"))
        XCTAssertTrue(rawValues.contains("其他"))
    }

    func testEntryDefaultLanguage() async throws {
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertEqual(entry.language, "日版", "Default language should be 日版")
    }

    func testLanguageSavedAndLoaded() async throws {
        let entryItem = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date(),
            language: "美版"
        )

        let entry = persistence.createEntry(from: entryItem)
        XCTAssertEqual(entry.language, "美版")

        let fetched = persistence.fetchAllEntries()
        let item = fetched.first!.toItem()
        XCTAssertEqual(item.language, "美版")
    }

    func testLanguageFilter() async throws {
        let entry1 = CardEntryItem(
            id: UUID(), nickname: "JP Card", subcards: [SubCardItem(
                id: UUID(), name: "Card1", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date(),
            language: "日版"
        )
        let entry2 = CardEntryItem(
            id: UUID(), nickname: "EN Card", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date(),
            language: "美版"
        )

        let items = [entry1, entry2]
        let japanese = items.filter { $0.language == "日版" }
        let english = items.filter { $0.language == "美版" }

        XCTAssertEqual(japanese.count, 1)
        XCTAssertEqual(english.count, 1)
        XCTAssertEqual(japanese.first?.nickname, "JP Card")
        XCTAssertEqual(english.first?.nickname, "EN Card")
    }

    func testCombinedFilterLanguageAndPSA() async throws {
        let entry1 = CardEntryItem(
            id: UUID(), nickname: "JP PSA", subcards: [SubCardItem(
                id: UUID(), name: "Card1", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date(),
            language: "日版"
        )
        let entry2 = CardEntryItem(
            id: UUID(), nickname: "JP Raw", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: false, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date(),
            language: "日版"
        )
        let entry3 = CardEntryItem(
            id: UUID(), nickname: "EN PSA", subcards: [SubCardItem(
                id: UUID(), name: "Card3", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date(),
            language: "美版"
        )

        let items = [entry1, entry2, entry3]

        let psaOnly = items.filter { $0.hasPSA }
        XCTAssertEqual(psaOnly.count, 2)

        let japanesePSA = items.filter { $0.hasPSA && $0.language == "日版" }
        XCTAssertEqual(japanesePSA.count, 1)
        XCTAssertEqual(japanesePSA.first?.nickname, "JP PSA")
    }

    // MARK: - Feature 1: Dashboard Refactored

    func testDashboardViewModelLoadsData() async throws {
        let entryItem = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 100.0,
            createdAt: Date(), updatedAt: Date()
        )
        persistence.createEntry(from: entryItem)

        let viewModel = DashboardViewModel(persistence: persistence)
        viewModel.loadDashboard()

        XCTAssertGreaterThanOrEqual(viewModel.totalEntries, 1)
        XCTAssertGreaterThanOrEqual(viewModel.totalCards, 1)
        XCTAssertGreaterThanOrEqual(viewModel.psaCount, 1)
    }

    func testDashboardViewModelLanguageCounts() async throws {
        let entry1 = CardEntryItem(
            id: UUID(), nickname: "JP", subcards: [SubCardItem(
                id: UUID(), name: "Card1", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date(),
            language: "日版"
        )
        let entry2 = CardEntryItem(
            id: UUID(), nickname: "EN", subcards: [SubCardItem(
                id: UUID(), name: "Card2", isPSA: true, sortOrder: 0
            )],
            createdAt: Date(), updatedAt: Date(),
            language: "美版"
        )
        persistence.createEntry(from: entry1)
        persistence.createEntry(from: entry2)

        let viewModel = DashboardViewModel(persistence: persistence)
        viewModel.loadDashboard()

        XCTAssertGreaterThanOrEqual(viewModel.languageCounts.count, 2, "Should have at least 2 languages")
    }

    func testDashboardViewModelInvestment() async throws {
        let entry = CardEntryItem(
            id: UUID(), nickname: "InvestTest", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 500.0, sellDate: Date(), sellPrice: 800.0,
            createdAt: Date(), updatedAt: Date()
        )
        let created = persistence.createEntry(from: entry)
        XCTAssertTrue(created.isSold, "Created entry should be sold")

        let viewModel = DashboardViewModel(persistence: persistence)
        viewModel.loadDashboard()

        XCTAssertGreaterThanOrEqual(viewModel.totalInvestment, 500.0, "Total investment should include 500")
        XCTAssertGreaterThanOrEqual(viewModel.soldCount, 1, "Should have at least 1 sold entry")
    }

    // MARK: - Feature 2: Edit Card Info

    func testEditCardUpdateSubcardName() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Original", isPSA: true,
            grade: "10", gradeDescription: "PSA 10", sortOrder: 0
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let viewModel = EditCardEntryViewModel(entry: entry, persistence: persistence)
        XCTAssertEqual(viewModel.subcards[0].name, "Original")

        viewModel.updateSubcardName(at: 0, "Updated")
        XCTAssertEqual(viewModel.subcards[0].name, "Updated")
    }

    func testEditCardUpdateSubcardGrade() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "9", gradeDescription: "PSA 9", sortOrder: 0
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let viewModel = EditCardEntryViewModel(entry: entry, persistence: persistence)
        XCTAssertEqual(viewModel.subcards[0].grade, "9")

        viewModel.updateSubcardGrade(at: 0, "10")
        XCTAssertEqual(viewModel.subcards[0].grade, "10")
        XCTAssertEqual(viewModel.subcards[0].gradeDescription, "PSA 10")
    }

    func testEditCardUpdateSubcardSetAndNumber() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true, sortOrder: 0
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let viewModel = EditCardEntryViewModel(entry: entry, persistence: persistence)
        XCTAssertNil(viewModel.subcards[0].set)
        XCTAssertNil(viewModel.subcards[0].number)

        viewModel.updateSubcardSet(at: 0, "Base Set")
        viewModel.updateSubcardNumber(at: 0, "001")

        XCTAssertEqual(viewModel.subcards[0].set, "Base Set")
        XCTAssertEqual(viewModel.subcards[0].number, "001")

        viewModel.updateSubcardSet(at: 0, "")
        viewModel.updateSubcardNumber(at: 0, "")

        XCTAssertNil(viewModel.subcards[0].set)
        XCTAssertNil(viewModel.subcards[0].number)
    }

    func testEditCardSavePersistsChanges() async throws {
        let cardId = UUID()
        let entryId = UUID()
        let card = SubCardItem(
            id: cardId, name: "Original", isPSA: true,
            grade: "9", gradeDescription: "PSA 9", sortOrder: 0
        )
        let entryItem = CardEntryItem(
            id: entryId, nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )
        let _ = persistence.createEntry(from: entryItem)

        let updatedCard = SubCardItem(
            id: cardId, name: "Updated", isPSA: true,
            grade: "10", gradeDescription: "PSA 10", sortOrder: 0
        )
        let updatedItem = CardEntryItem(
            id: entryId, nickname: "Test", subcards: [updatedCard],
            createdAt: Date(), updatedAt: Date()
        )

        let allEntries = persistence.fetchAllEntries()
        let saved = allEntries.first { $0.id == entryId }
        XCTAssertNotNil(saved)

        persistence.updateEntry(saved!, with: updatedItem)

        let afterUpdate = persistence.fetchAllEntries()
        let updated = afterUpdate.first { $0.id == entryId }
        XCTAssertNotNil(updated)
        let updatedResult = updated!.toItem()
        XCTAssertEqual(updatedResult.subcards[0].name, "Updated")
        XCTAssertEqual(updatedResult.subcards[0].grade, "10")
    }

    // MARK: - Feature 1: Price Hiding

    func testUserPreferencesDefaultHidePrices() async throws {
        let prefs = UserPreferences.shared
        let original = prefs.hidePrices
        prefs.hidePrices = false
        XCTAssertFalse(prefs.hidePrices, "Should show prices when set to false")
        prefs.hidePrices = original
    }

    func testUserPreferencesToggleHidePrices() async throws {
        let prefs = UserPreferences.shared
        let original = prefs.hidePrices
        prefs.hidePrices = true
        XCTAssertTrue(prefs.hidePrices)
        prefs.hidePrices = false
        XCTAssertFalse(prefs.hidePrices)
        prefs.hidePrices = original
    }

    func testEntryGridItemHidesPrice() async throws {
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, sortOrder: 0
            )],
            purchasePrice: 500.0,
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertNotNil(entry.purchasePrice)
        XCTAssertEqual(entry.purchasePrice, 500.0)
    }

    // MARK: - UI 3: Grading Company

    func testGradingCompanyDefault() async throws {
        XCTAssertEqual(GradingCompany.default, .psa)
        XCTAssertEqual(GradingCompany.default.rawValue, "PSA")
    }

    func testGradingCompanyAllCases() async throws {
        XCTAssertEqual(GradingCompany.allCases.count, 4)
        let rawValues = GradingCompany.allCases.map { $0.rawValue }
        XCTAssertTrue(rawValues.contains("PSA"))
        XCTAssertTrue(rawValues.contains("CCIC"))
        XCTAssertTrue(rawValues.contains("BGS"))
        XCTAssertTrue(rawValues.contains("其他"))
    }

    func testSubCardDefaultGradingCompany() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true, sortOrder: 0
        )
        XCTAssertEqual(card.gradingCompany, "PSA")
        XCTAssertEqual(card.gradingCompanyEnum, .psa)
    }

    func testSubCardGradingCompanyDisplay() async throws {
        let psaCard = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "10", sortOrder: 0
        )
        XCTAssertEqual(psaCard.gradeDisplay, "PSA 10")

        let ccicCard = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "金10", sortOrder: 0, gradingCompany: "CCIC"
        )
        XCTAssertEqual(ccicCard.gradeDisplay, "CCIC 金10")

        let bgsCard = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "9.5", sortOrder: 0, gradingCompany: "BGS"
        )
        XCTAssertEqual(bgsCard.gradeDisplay, "BGS 9.5")
    }

    func testGradingCompanyColors() async throws {
        XCTAssertEqual(GradingCompany.psa.displayColor, .orange)
        XCTAssertEqual(GradingCompany.ccic.displayColor, .red)
        XCTAssertEqual(GradingCompany.bgs.displayColor, .blue)
        XCTAssertEqual(GradingCompany.other.displayColor, .gray)
    }

    // MARK: - Grade Dropdown Feature

    func testPSAGradeOptions() async throws {
        let options = GradingCompany.psa.gradeOptions
        XCTAssertEqual(options, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])
    }

    func testCCICGradeOptions() async throws {
        let options = GradingCompany.ccic.gradeOptions
        XCTAssertEqual(options, ["银10", "金10"])
    }

    func testBGSGradeOptions() async throws {
        let options = GradingCompany.bgs.gradeOptions
        XCTAssertEqual(options, ["9.5", "10", "黑10"])
    }

    func testOtherGradeIsFreeTextInput() async throws {
        XCTAssertTrue(GradingCompany.other.isFreeTextInput)
        XCTAssertTrue(GradingCompany.other.gradeOptions.isEmpty)
        XCTAssertFalse(GradingCompany.psa.isFreeTextInput)
        XCTAssertFalse(GradingCompany.ccic.isFreeTextInput)
        XCTAssertFalse(GradingCompany.bgs.isFreeTextInput)
    }

    func testGradeIntConversion() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "10", sortOrder: 0
        )
        XCTAssertEqual(card.gradeInt, 10)

        let cardNonNumeric = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "金10", sortOrder: 0, gradingCompany: "CCIC"
        )
        XCTAssertNil(cardNonNumeric.gradeInt)
    }

    func testGradingCompanyChangeClearsInvalidGrade() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "10", sortOrder: 0, gradingCompany: "PSA"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let viewModel = EditCardEntryViewModel(entry: entry, persistence: persistence)
        XCTAssertEqual(viewModel.subcards[0].grade, "10")

        viewModel.updateSubcardGradingCompany(at: 0, "CCIC")
        XCTAssertNil(viewModel.subcards[0].grade, "Grade should be cleared when switching to CCIC since '10' is not a CCIC option")
    }

    func testGradingCompanyChangeKeepsValidGrade() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "10", sortOrder: 0, gradingCompany: "PSA"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let viewModel = EditCardEntryViewModel(entry: entry, persistence: persistence)
        XCTAssertEqual(viewModel.subcards[0].grade, "10")

        viewModel.updateSubcardGradingCompany(at: 0, "BGS")
        XCTAssertEqual(viewModel.subcards[0].grade, "10", "Grade '10' should be kept as it's valid for BGS")
    }

    func testGradingCompanyOtherClearsGrade() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "10", sortOrder: 0, gradingCompany: "PSA"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let viewModel = EditCardEntryViewModel(entry: entry, persistence: persistence)
        viewModel.updateSubcardGradingCompany(at: 0, "其他")
        XCTAssertNil(viewModel.subcards[0].grade, "Grade should be cleared for '其他' free text input")
    }

    func testOtherGradingCompanyFreeTextInput() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "PRISTINE", sortOrder: 0, gradingCompany: "其他"
        )
        XCTAssertEqual(card.grade, "PRISTINE")
        XCTAssertEqual(card.gradeDisplay, "其他 PRISTINE")
    }

    func testGradeSavedAsStringInCoreData() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "金10", sortOrder: 0, gradingCompany: "CCIC"
        )
        let entryItem = CardEntryItem(
            id: UUID(), nickname: "CCIC Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)
        let subcards = entry.subcardsSorted
        XCTAssertEqual(subcards.first?.grade, "金10")
        XCTAssertEqual(subcards.first?.gradingCompany, "CCIC")

        let fetched = persistence.fetchAllEntries()
        let fetchedItem = fetched.first?.toItem()
        XCTAssertEqual(fetchedItem?.subcards.first?.grade, "金10")
        XCTAssertEqual(fetchedItem?.subcards.first?.gradingCompany, "CCIC")
    }

    func testEditCardUpdateGradingCompanyAndGrade() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "10", sortOrder: 0, gradingCompany: "PSA"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let viewModel = EditCardEntryViewModel(entry: entry, persistence: persistence)

        viewModel.updateSubcardGradingCompany(at: 0, "CCIC")
        XCTAssertNil(viewModel.subcards[0].grade)

        viewModel.updateSubcardGrade(at: 0, "银10")
        XCTAssertEqual(viewModel.subcards[0].grade, "银10")
        XCTAssertEqual(viewModel.subcards[0].gradeDescription, "CCIC 银10")
    }

    // MARK: - Bug Fix: Image Add Button Error "选择评级公司"

    func testGradingCompanyNeverEmptyInViewModel() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "10", sortOrder: 0, gradingCompany: ""
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let viewModel = EditCardEntryViewModel(entry: entry, persistence: persistence)
        XCTAssertFalse(viewModel.subcards[0].gradingCompany.isEmpty, "gradingCompany should never be empty after ViewModel init")
        XCTAssertEqual(viewModel.subcards[0].gradingCompanyEnum, .psa, "Empty gradingCompany should default to PSA")
    }

    func testGradingCompanyEnumHandlesEmptyString() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true, sortOrder: 0,
            gradingCompany: ""
        )
        XCTAssertEqual(card.gradingCompanyEnum, .psa, "Empty gradingCompany should resolve to PSA default")
    }

    func testGradingCompanyEnumHandlesNilFromCoreData() async throws {
        let entryItem = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [SubCardItem(
                id: UUID(), name: "Card", isPSA: true, grade: "10", sortOrder: 0
            )],
            purchasePrice: 100.0, createdAt: Date(), updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)
        let item = entry.toItem()
        XCTAssertEqual(item.subcards.first?.gradingCompany, "PSA", "Default gradingCompany should be PSA")
        XCTAssertEqual(item.subcards.first?.gradingCompanyEnum, .psa)
    }

    func testImageAddIndependentOfGradingCompany() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: nil, sortOrder: 0
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let viewModel = EditCardEntryViewModel(entry: entry, persistence: persistence)

        XCTAssertNotNil(viewModel.subcards[0].gradingCompany, "gradingCompany should have a value")
        XCTAssertFalse(viewModel.subcards[0].gradingCompany.isEmpty, "gradingCompany should not be empty")

        viewModel.updateSubcardGrade(at: 0, "10")
        XCTAssertEqual(viewModel.subcards[0].grade, "10")
        XCTAssertEqual(viewModel.subcards[0].gradingCompany, "PSA")
    }

    func testPickerSelectionAlwaysMatchesTag() async throws {
        for company in GradingCompany.allCases {
            let card = SubCardItem(
                id: UUID(), name: "Card", isPSA: true,
                grade: company.gradeOptions.first, sortOrder: 0,
                gradingCompany: company.rawValue
            )
            let selectionValue = card.gradingCompany.isEmpty ? GradingCompany.default.rawValue : card.gradingCompany
            let matchesTag = GradingCompany.allCases.contains { $0.rawValue == selectionValue }
            XCTAssertTrue(matchesTag, "Picker selection '\(selectionValue)' must match a GradingCompany tag")
        }
    }

    // MARK: - Bug Fix: Export/Import Consistency

    func testCSVExportImportRoundTrip() async throws {
        let card = SubCardItem(
            id: UUID(), name: "PIKACHU", set: "SET1", number: "020",
            isPSA: true, psaCertNumber: nil, grade: "10",
            population: 100, populationHigher: 0,
            psaImageFrontPath: "PSAImages/PSA_test_front.jpg",
            psaImageBackPath: "PSAImages/PSA_test_back.jpg",
            localImagePath: nil, year: "2025", variety: "McDONALD'S",
            gradeDescription: "GEM MT 10", category: "TCG Cards",
            labelType: "LighthouseLabel", sortOrder: 0,
            gradingCompany: "PSA"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test Entry", subcards: [card],
            purchasePrice: 100.0, sellDate: Date(), sellPrice: 200.0,
            note: "Test note", createdAt: Date(), updatedAt: Date()
        )

        let exportURL = CSVExportService.export(entries: [entry])
        XCTAssertNotNil(exportURL, "CSV export should succeed")

        let importedEntries = CSVImportService.importFrom(url: exportURL!)
        XCTAssertNotNil(importedEntries, "CSV import should succeed")
        XCTAssertEqual(importedEntries?.count, 1, "Should import 1 entry")

        let importedEntry = importedEntries!.first!
        XCTAssertEqual(importedEntry.nickname, "Test Entry")
        XCTAssertEqual(importedEntry.subcards.count, 1)
        XCTAssertEqual(importedEntry.subcards.first?.name, "PIKACHU")
        XCTAssertEqual(importedEntry.subcards.first?.grade, "10")
        XCTAssertEqual(importedEntry.subcards.first?.gradingCompany, "PSA")
        XCTAssertEqual(importedEntry.subcards.first?.isPSA, true)
        XCTAssertEqual(importedEntry.subcards.first?.gradeDescription, "GEM MT 10")
    }

    func testCSVExportImportCCICCard() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "金10", sortOrder: 0,
            gradingCompany: "CCIC"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "CCIC Test", subcards: [card],
            purchasePrice: 500.0, createdAt: Date(), updatedAt: Date()
        )

        let exportURL = CSVExportService.export(entries: [entry])
        XCTAssertNotNil(exportURL)

        let importedEntries = CSVImportService.importFrom(url: exportURL!)
        XCTAssertNotNil(importedEntries)
        XCTAssertEqual(importedEntries?.first?.subcards.first?.grade, "金10")
        XCTAssertEqual(importedEntries?.first?.subcards.first?.gradingCompany, "CCIC")
    }

    func testCSVExportImportBGSCard() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "黑10", sortOrder: 0,
            gradingCompany: "BGS"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "BGS Test", subcards: [card],
            purchasePrice: 300.0, createdAt: Date(), updatedAt: Date()
        )

        let exportURL = CSVExportService.export(entries: [entry])
        XCTAssertNotNil(exportURL)

        let importedEntries = CSVImportService.importFrom(url: exportURL!)
        XCTAssertNotNil(importedEntries)
        XCTAssertEqual(importedEntries?.first?.subcards.first?.grade, "黑10")
        XCTAssertEqual(importedEntries?.first?.subcards.first?.gradingCompany, "BGS")
    }

    func testCSVExportImportRawCard() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Raw Card", isPSA: false,
            grade: nil, sortOrder: 0
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Raw Test", subcards: [card],
            purchasePrice: 50.0, createdAt: Date(), updatedAt: Date()
        )

        let exportURL = CSVExportService.export(entries: [entry])
        XCTAssertNotNil(exportURL)

        let importedEntries = CSVImportService.importFrom(url: exportURL!)
        XCTAssertNotNil(importedEntries)
        let importedCard = importedEntries!.first?.subcards.first
        XCTAssertEqual(importedCard?.name, "Raw Card")
        XCTAssertEqual(importedCard?.isPSA, false)
        XCTAssertNil(importedCard?.grade)
    }

    func testCSVExportImportOtherGradingCompany() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "PRISTINE", sortOrder: 0,
            gradingCompany: "其他"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Other Test", subcards: [card],
            purchasePrice: 100.0, createdAt: Date(), updatedAt: Date()
        )

        let exportURL = CSVExportService.export(entries: [entry])
        XCTAssertNotNil(exportURL)

        let importedEntries = CSVImportService.importFrom(url: exportURL!)
        XCTAssertNotNil(importedEntries)
        XCTAssertEqual(importedEntries?.first?.subcards.first?.grade, "PRISTINE")
        XCTAssertEqual(importedEntries?.first?.subcards.first?.gradingCompany, "其他")
    }

    func testCSVExportHeaderMatchesImportColumns() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "10", sortOrder: 0, gradingCompany: "PSA"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let exportURL = CSVExportService.export(entries: [entry])
        XCTAssertNotNil(exportURL)

        let content = try! String(contentsOf: exportURL!, encoding: .utf8)
        let headerLine = content.components(separatedBy: "\n").first ?? ""
        let headers = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        XCTAssertTrue(headers.contains("评级公司"), "CSV header must contain '评级公司' column")
        XCTAssertTrue(headers.contains("评级分数"), "CSV header must contain '评级分数' column")
        XCTAssertTrue(headers.contains("评级描述"), "CSV header must contain '评级描述' column")
    }

    func testJSONExportFileExtension() async throws {
        let card = SubCardItem(
            id: UUID(), name: "Card", isPSA: true,
            grade: "10", sortOrder: 0
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "Test", subcards: [card],
            createdAt: Date(), updatedAt: Date()
        )

        let exportURL = await ArchiveExportService.shared.export(entries: [entry])
        XCTAssertNotNil(exportURL)
        XCTAssertTrue(exportURL!.pathExtension == "json", "Export file should have .json extension")
    }

    func testJSONExportImportRoundTrip() async throws {
        let card = SubCardItem(
            id: UUID(), name: "PIKACHU", set: "SET1", number: "020",
            isPSA: true, psaCertNumber: "12345", grade: "10",
            population: 100, populationHigher: 0,
            psaImageFrontPath: nil, psaImageBackPath: nil,
            localImagePath: nil, year: "2025", variety: "Holo",
            gradeDescription: "GEM MT 10", category: "TCG",
            labelType: "Standard", sortOrder: 0,
            gradingCompany: "PSA"
        )
        let entry = CardEntryItem(
            id: UUID(), nickname: "JSON Test", subcards: [card],
            purchasePrice: 100.0, sellDate: nil, sellPrice: nil,
            note: "JSON round trip", createdAt: Date(), updatedAt: Date(),
            askingPrice: 150.0, language: "日版"
        )

        let exportURL = await ArchiveExportService.shared.export(entries: [entry])
        XCTAssertNotNil(exportURL)

        let importedEntries = await ArchiveImportService.shared.import(from: exportURL!)
        XCTAssertNotNil(importedEntries)
        XCTAssertEqual(importedEntries?.count, 1)

        let imported = importedEntries!.first!
        XCTAssertEqual(imported.nickname, "JSON Test")
        XCTAssertEqual(imported.subcards.first?.name, "PIKACHU")
        XCTAssertEqual(imported.subcards.first?.grade, "10")
        XCTAssertEqual(imported.subcards.first?.gradingCompany, "PSA")
        XCTAssertEqual(imported.subcards.first?.isPSA, true)
        XCTAssertEqual(imported.language, "日版")
        XCTAssertEqual(imported.askingPrice, 150.0)
    }

    func testCSVImportOldFormatBackwardCompatibility() async throws {
        let oldCSV = "昵称,卡名,系列,编号,是否评级,评级,Pop,年份,变体,购买日期,购买价格(¥),出售日期,出售价格(¥),盈亏(¥),备注,正面图片路径,背面图片路径\nTest,PIKACHU,SET1,020,是,GEM MT 10,100,2025,,2025-01-01,100.00,,,,,,,\n"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_old_format.csv")
        try oldCSV.write(to: tempURL, atomically: true, encoding: .utf8)

        let entries = CSVImportService.importFrom(url: tempURL)
        XCTAssertNotNil(entries, "Should import old CSV format")
        XCTAssertEqual(entries?.count, 1)
        XCTAssertEqual(entries?.first?.subcards.first?.name, "PIKACHU")
        XCTAssertEqual(entries?.first?.subcards.first?.isPSA, true)

        try? FileManager.default.removeItem(at: tempURL)
    }
}
