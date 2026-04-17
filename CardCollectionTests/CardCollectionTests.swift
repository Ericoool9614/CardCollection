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
            XCTAssertEqual(sub.name, "PIKACHU", "Subcard name should be PIKACHU")
            XCTAssertEqual(sub.set, "POKEMON JAPANESE M-P PROMO")
            XCTAssertEqual(sub.isPSA, true)
            XCTAssertEqual(sub.psaCertNumber, "133880310")
            XCTAssertEqual(sub.grade, 10)
            XCTAssertEqual(sub.gradeDescription, "GEM MT 10")
            XCTAssertEqual(sub.number, "020")
            XCTAssertEqual(sub.year, "2025")
            XCTAssertEqual(sub.variety, "McDONALD'S")
            XCTAssertEqual(sub.category, "TCG Cards")
            XCTAssertEqual(sub.labelType, "LighthouseLabel")
            XCTAssertEqual(sub.psaImageFrontPath, "PSAImages/PSA_133880310_front.jpg")
            XCTAssertEqual(sub.psaImageBackPath, "PSAImages/PSA_133880310_back.jpg")
        }
        
        let fetched = persistence.fetchAllEntries()
        XCTAssertEqual(fetched.count, 1, "Should have 1 entry in DB")
        
        if let fetchedEntry = fetched.first {
            let item = fetchedEntry.toItem()
            XCTAssertEqual(item.nickname, "My Pikachu")
            XCTAssertEqual(item.subcards.count, 1, "Fetched entry should have 1 subcard")
            XCTAssertEqual(item.subcards.first?.name, "PIKACHU", "Fetched subcard name should be PIKACHU")
            XCTAssertEqual(item.subcards.first?.isPSA, true)
            XCTAssertEqual(item.subcards.first?.grade, 10)
            XCTAssertEqual(item.subcards.first?.psaCertNumber, "133880310")
            XCTAssertEqual(item.subcards.first?.set, "POKEMON JAPANESE M-P PROMO")
        }
    }

    func testPSAServiceFetchAndSave() async throws {
        let result = try await PSAService.shared.fetchCard(certNumber: "133880310")
        
        XCTAssertEqual(result.cardName, "PIKACHU")
        XCTAssertEqual(result.cardSet, "POKEMON JAPANESE M-P PROMO")
        XCTAssertEqual(result.cardNumber, "020")
        XCTAssertEqual(result.grade, 10)
        XCTAssertEqual(result.gradeDescription, "GEM MT 10")
        XCTAssertEqual(result.year, "2025")
        XCTAssertEqual(result.variety, "McDONALD'S")
        XCTAssertEqual(result.category, "TCG Cards")
        XCTAssertEqual(result.labelType, "LighthouseLabel")
        
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
        let item = fetched.first!.toItem()
        XCTAssertEqual(item.subcards.first?.name, "PIKACHU")
        XCTAssertEqual(item.subcards.first?.isPSA, true)
        XCTAssertEqual(item.subcards.first?.grade, 10)
    }

    func testMultipleSubcardsInEntry() async throws {
        let sub1 = SubCardItem(
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
        
        let sub2 = SubCardItem(
            id: UUID(),
            name: "CHARIZARD",
            set: "POKEMON BASE SET",
            number: "004",
            isPSA: true,
            psaCertNumber: "999999999",
            grade: 9,
            population: 1000,
            populationHigher: 50,
            psaImageFrontPath: "PSAImages/PSA_999999999_front.jpg",
            psaImageBackPath: "PSAImages/PSA_999999999_back.jpg",
            localImagePath: nil,
            year: "1999",
            variety: nil,
            gradeDescription: "MINT 9",
            category: "TCG Cards",
            labelType: "StandardLabel",
            sortOrder: 1
        )
        
        let entryItem = CardEntryItem(
            id: UUID(),
            nickname: "My Collection",
            subcards: [sub1, sub2],
            purchaseDate: Date(),
            purchasePrice: 500.0,
            sellDate: nil,
            sellPrice: nil,
            note: "Two cards",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let entry = persistence.createEntry(from: entryItem)
        let subcards = entry.subcardsSorted
        XCTAssertEqual(subcards.count, 2, "Should have 2 subcards")
        XCTAssertEqual(subcards[0].name, "PIKACHU")
        XCTAssertEqual(subcards[1].name, "CHARIZARD")
        
        let item = entry.toItem()
        XCTAssertEqual(item.cardCount, 2)
        XCTAssertEqual(item.primaryCard?.name, "PIKACHU")
    }

    func testThumbnailUsesFirstCardImage() async throws {
        let sub1 = SubCardItem(
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

        let sub2 = SubCardItem(
            id: UUID(),
            name: "CHARIZARD",
            set: "POKEMON BASE SET",
            number: "004",
            isPSA: true,
            psaCertNumber: "999999999",
            grade: 9,
            population: 1000,
            populationHigher: 50,
            psaImageFrontPath: "PSAImages/PSA_999999999_front.jpg",
            psaImageBackPath: "PSAImages/PSA_999999999_back.jpg",
            localImagePath: nil,
            year: "1999",
            variety: nil,
            gradeDescription: "MINT 9",
            category: "TCG Cards",
            labelType: "StandardLabel",
            sortOrder: 1
        )

        let entryItem = CardEntryItem(
            id: UUID(),
            nickname: "My Collection",
            subcards: [sub1, sub2],
            purchaseDate: Date(),
            purchasePrice: 500.0,
            sellDate: nil,
            sellPrice: nil,
            note: "Two cards",
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)
        let item = entry.toItem()

        XCTAssertEqual(item.primaryCard?.name, "PIKACHU")
        XCTAssertEqual(item.primaryCard?.psaImageFrontPath, "PSAImages/PSA_133880310_front.jpg")

        let firstCardImagePath = item.subcards.first?.psaImageFrontPath ?? item.subcards.first?.localImagePath
        XCTAssertEqual(firstCardImagePath, "PSAImages/PSA_133880310_front.jpg", "Thumbnail should use first card's front image")
    }

    func testRawCardThumbnailUsesLocalImage() async throws {
        let sub1 = SubCardItem(
            id: UUID(),
            name: "My Raw Card",
            set: "SOME SET",
            number: "001",
            isPSA: false,
            psaCertNumber: nil,
            grade: nil,
            population: nil,
            populationHigher: nil,
            psaImageFrontPath: nil,
            psaImageBackPath: nil,
            localImagePath: "LocalImages/Local_test.jpg",
            year: nil,
            variety: nil,
            gradeDescription: nil,
            category: nil,
            labelType: nil,
            sortOrder: 0
        )

        let entryItem = CardEntryItem(
            id: UUID(),
            nickname: "Raw Card Entry",
            subcards: [sub1],
            purchaseDate: Date(),
            purchasePrice: 50.0,
            sellDate: nil,
            sellPrice: nil,
            note: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let entry = persistence.createEntry(from: entryItem)
        let item = entry.toItem()

        let firstCardImagePath = item.subcards.first?.psaImageFrontPath ?? item.subcards.first?.localImagePath
        XCTAssertEqual(firstCardImagePath, "LocalImages/Local_test.jpg", "Raw card thumbnail should use localImagePath")
        XCTAssertEqual(item.subcards.first?.isPSA, false)
    }
}
