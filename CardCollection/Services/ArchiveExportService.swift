import Foundation

actor ArchiveExportService {
    static let shared = ArchiveExportService()

    func export(entries: [CardEntryItem]) async -> URL? {
        let isoFormatter = ISO8601DateFormatter()
        var jsonEntries: [[String: Any]] = []

        for entry in entries {
            var entryDict: [String: Any] = [
                "id": entry.id.uuidString,
                "nickname": entry.nickname as Any,
                "purchasePrice": entry.purchasePrice as Any,
                "sellPrice": entry.sellPrice as Any,
                "note": entry.note as Any,
                "askingPrice": entry.askingPrice as Any
            ]

            if let d = entry.purchaseDate {
                entryDict["purchaseDate"] = isoFormatter.string(from: d)
            }
            if let d = entry.sellDate {
                entryDict["sellDate"] = isoFormatter.string(from: d)
            }
            entryDict["createdAt"] = isoFormatter.string(from: entry.createdAt)
            entryDict["updatedAt"] = isoFormatter.string(from: entry.updatedAt)

            var subcardsArray: [[String: Any]] = []
            for card in entry.subcards {
                var dict: [String: Any] = [
                    "id": card.id.uuidString,
                    "name": card.name,
                    "set": card.set as Any,
                    "number": card.number as Any,
                    "isPSA": card.isPSA,
                    "psaCertNumber": card.psaCertNumber as Any,
                    "grade": card.grade as Any,
                    "population": card.population as Any,
                    "populationHigher": card.populationHigher as Any,
                    "psaImageFrontPath": card.psaImageFrontPath as Any,
                    "psaImageBackPath": card.psaImageBackPath as Any,
                    "localImagePath": card.localImagePath as Any,
                    "year": card.year as Any,
                    "variety": card.variety as Any,
                    "gradeDescription": card.gradeDescription as Any,
                    "category": card.category as Any,
                    "labelType": card.labelType as Any,
                    "sortOrder": card.sortOrder
                ]

                if let path = card.psaImageFrontPath, !path.isEmpty {
                    let resolved = ImageStorageService.resolvePath(path)
                    if FileManager.default.fileExists(atPath: resolved),
                       let data = try? Data(contentsOf: URL(fileURLWithPath: resolved)) {
                        dict["psaImageFrontData"] = data.base64EncodedString()
                    }
                }
                if let path = card.psaImageBackPath, !path.isEmpty {
                    let resolved = ImageStorageService.resolvePath(path)
                    if FileManager.default.fileExists(atPath: resolved),
                       let data = try? Data(contentsOf: URL(fileURLWithPath: resolved)) {
                        dict["psaImageBackData"] = data.base64EncodedString()
                    }
                }
                if let path = card.localImagePath, !path.isEmpty {
                    let resolved = ImageStorageService.resolvePath(path)
                    if FileManager.default.fileExists(atPath: resolved),
                       let data = try? Data(contentsOf: URL(fileURLWithPath: resolved)) {
                        dict["localImageData"] = data.base64EncodedString()
                    }
                }

                subcardsArray.append(dict)
            }

            entryDict["subcards"] = subcardsArray
            jsonEntries.append(entryDict)
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonEntries, options: .prettyPrinted)
            let archiveName = "卡牌收藏_导出_\(formatDateForFilename(Date())).ccdata"
            let archiveURL = FileManager.default.temporaryDirectory.appendingPathComponent(archiveName)
            try jsonData.write(to: archiveURL)
            return archiveURL
        } catch {
            return nil
        }
    }

    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: date)
    }
}

actor ArchiveImportService {
    static let shared = ArchiveImportService()

    func `import`(from url: URL) -> [CardEntryItem]? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        if let data = try? Data(contentsOf: url),
           let jsonEntries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return parseJSONEntries(jsonEntries)
        }

        return CSVImportService.importFrom(url: url)
    }

    private func parseJSONEntries(_ jsonEntries: [[String: Any]]) -> [CardEntryItem] {
        let isoFormatter = ISO8601DateFormatter()
        var entries: [CardEntryItem] = []

        for entryDict in jsonEntries {
            let id = UUID(uuidString: entryDict["id"] as? String ?? "") ?? UUID()
            let nickname = entryDict["nickname"] as? String

            var subcards: [SubCardItem] = []
            if let subcardDicts = entryDict["subcards"] as? [[String: Any]] {
                for subDict in subcardDicts {
                    let subId = UUID(uuidString: subDict["id"] as? String ?? "") ?? UUID()

                    var frontPath: String? = subDict["psaImageFrontPath"] as? String
                    var backPath: String? = subDict["psaImageBackPath"] as? String
                    var localPath: String? = subDict["localImagePath"] as? String

                    if let b64 = subDict["psaImageFrontData"] as? String,
                       let data = Data(base64Encoded: b64) {
                        let fileName = "PSA_import_\(subId.uuidString)_front.jpg"
                        let destDir = ImageStorageService.documentsDirectory.appendingPathComponent("PSAImages")
                        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                        let destPath = destDir.appendingPathComponent(fileName)
                        try? data.write(to: destPath)
                        frontPath = "PSAImages/\(fileName)"
                    }
                    if let b64 = subDict["psaImageBackData"] as? String,
                       let data = Data(base64Encoded: b64) {
                        let fileName = "PSA_import_\(subId.uuidString)_back.jpg"
                        let destDir = ImageStorageService.documentsDirectory.appendingPathComponent("PSAImages")
                        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                        let destPath = destDir.appendingPathComponent(fileName)
                        try? data.write(to: destPath)
                        backPath = "PSAImages/\(fileName)"
                    }
                    if let b64 = subDict["localImageData"] as? String,
                       let data = Data(base64Encoded: b64) {
                        let fileName = "Local_import_\(subId.uuidString).jpg"
                        let destDir = ImageStorageService.documentsDirectory.appendingPathComponent("LocalImages")
                        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                        let destPath = destDir.appendingPathComponent(fileName)
                        try? data.write(to: destPath)
                        localPath = "LocalImages/\(fileName)"
                    }

                    let subcard = SubCardItem(
                        id: subId,
                        name: subDict["name"] as? String ?? "",
                        set: subDict["set"] as? String,
                        number: subDict["number"] as? String,
                        isPSA: subDict["isPSA"] as? Bool ?? false,
                        psaCertNumber: subDict["psaCertNumber"] as? String,
                        grade: subDict["grade"] as? Int,
                        population: subDict["population"] as? Int,
                        populationHigher: subDict["populationHigher"] as? Int,
                        psaImageFrontPath: frontPath,
                        psaImageBackPath: backPath,
                        localImagePath: localPath,
                        year: subDict["year"] as? String,
                        variety: subDict["variety"] as? String,
                        gradeDescription: subDict["gradeDescription"] as? String,
                        category: subDict["category"] as? String,
                        labelType: subDict["labelType"] as? String,
                        sortOrder: subDict["sortOrder"] as? Int ?? 0
                    )
                    subcards.append(subcard)
                }
            }

            let entry = CardEntryItem(
                id: id,
                nickname: nickname,
                subcards: subcards,
                purchaseDate: (entryDict["purchaseDate"] as? String).flatMap { isoFormatter.date(from: $0) },
                purchasePrice: entryDict["purchasePrice"] as? Double,
                sellDate: (entryDict["sellDate"] as? String).flatMap { isoFormatter.date(from: $0) },
                sellPrice: entryDict["sellPrice"] as? Double,
                note: entryDict["note"] as? String,
                createdAt: (entryDict["createdAt"] as? String).flatMap { isoFormatter.date(from: $0) } ?? Date(),
                updatedAt: (entryDict["updatedAt"] as? String).flatMap { isoFormatter.date(from: $0) } ?? Date(),
                askingPrice: entryDict["askingPrice"] as? Double
            )
            entries.append(entry)
        }

        return entries
    }
}
