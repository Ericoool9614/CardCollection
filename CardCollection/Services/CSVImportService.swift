import Foundation

struct CSVImportService {
    static func importFrom(url: URL) -> [CardEntryItem]? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }

        let header = parseCSVLine(lines[0])

        var entryMap: [String: (entry: CardEntryItem, subcards: [SubCardItem])] = [:]

        for i in 1..<lines.count {
            let fields = parseCSVLine(lines[i])
            guard fields.count >= 6 else { continue }

            let nickname = fields[safe: 0] ?? ""
            let name = fields[safe: 1] ?? ""
            let set = fields[safe: 2]?.isEmpty == true ? nil : fields[safe: 2]
            let number = fields[safe: 3]?.isEmpty == true ? nil : fields[safe: 3]
            let isPSAStr = fields[safe: 4] ?? "否"
            let isPSA = isPSAStr == "是"
            let gradeStr = fields[safe: 5] ?? ""
            let popStr = fields[safe: 6] ?? ""
            let year = fields[safe: 7]?.isEmpty == true ? nil : fields[safe: 7]
            let variety = fields[safe: 8]?.isEmpty == true ? nil : fields[safe: 8]
            let purchaseDateStr = fields[safe: 9] ?? ""
            let purchasePriceStr = fields[safe: 10] ?? ""
            let sellDateStr = fields[safe: 11] ?? ""
            let sellPriceStr = fields[safe: 12] ?? ""
            let profitStr = fields[safe: 13] ?? ""
            let notes = fields[safe: 14]?.isEmpty == true ? nil : fields[safe: 14]
            let frontImagePath = fields[safe: 15]?.isEmpty == true ? nil : fields[safe: 15]
            let backImagePath = fields[safe: 16]?.isEmpty == true ? nil : fields[safe: 16]

            let grade = parseGrade(from: gradeStr)
            let population = Int(popStr)
            let purchasePrice = Double(purchasePriceStr)
            let sellPrice = Double(sellPriceStr)
            let purchaseDate = parseDate(from: purchaseDateStr)
            let sellDate = parseDate(from: sellDateStr)

            let subcard = SubCardItem(
                id: UUID(),
                name: name,
                set: set,
                number: number,
                isPSA: isPSA,
                psaCertNumber: nil,
                grade: grade,
                population: population,
                populationHigher: nil,
                psaImageFrontPath: frontImagePath,
                psaImageBackPath: backImagePath,
                localImagePath: nil,
                year: year,
                variety: variety,
                gradeDescription: gradeStr.isEmpty ? nil : gradeStr,
                category: nil,
                labelType: nil,
                sortOrder: 0
            )

            let key = nickname + "_" + (purchaseDateStr) + "_" + (purchasePriceStr)

            if var existing = entryMap[key] {
                var newSub = subcard
                newSub.sortOrder = existing.subcards.count
                existing.subcards.append(newSub)
                entryMap[key] = existing
            } else {
                let entry = CardEntryItem(
                    id: UUID(),
                    nickname: nickname.isEmpty ? nil : nickname,
                    subcards: [subcard],
                    purchaseDate: purchaseDate,
                    purchasePrice: purchasePrice,
                    sellDate: sellDate,
                    sellPrice: sellPrice,
                    note: notes,
                    createdAt: Date(),
                    updatedAt: Date(),
                    askingPrice: nil
                )
                entryMap[key] = (entry: entry, subcards: [subcard])
            }
        }

        return entryMap.values.map { data in
            var entry = data.entry
            entry.subcards = data.subcards
            return entry
        }
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    private static func parseGrade(from str: String) -> Int? {
        let gradeMap: [String: Int] = [
            "GEM MT 10": 10, "MINT 9": 9, "NM-MT 8": 8, "NM 7": 7,
            "EXMT 6": 6, "EX 5": 5, "VG-EX 4": 4, "VG 3": 3,
            "GOOD 2": 2, "PR 1": 1
        ]
        if let g = gradeMap[str] { return g }
        if str.hasPrefix("PSA ") {
            return Int(str.replacingOccurrences(of: "PSA ", with: ""))
        }
        return Int(str)
    }

    private static func parseDate(from str: String) -> Date? {
        guard !str.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if let d = formatter.date(from: str) { return d }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
