import Foundation

struct CSVImportService {
    static func importFrom(url: URL) -> [CardEntryItem]? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }

        let header = parseCSVLine(lines[0])
        let columnMap = buildColumnMap(header: header)

        var entryMap: [String: (entry: CardEntryItem, subcards: [SubCardItem])] = [:]

        for i in 1..<lines.count {
            let fields = parseCSVLine(lines[i])
            guard fields.count >= 6 else { continue }

            let nickname = fields[safe: columnMap["昵称"]] ?? ""
            let name = fields[safe: columnMap["卡名"]] ?? ""
            let set = fields[safe: columnMap["系列"]]?.isEmpty == true ? nil : fields[safe: columnMap["系列"]]
            let number = fields[safe: columnMap["编号"]]?.isEmpty == true ? nil : fields[safe: columnMap["编号"]]
            let isPSAStr = fields[safe: columnMap["是否评级"]] ?? "否"
            let isPSA = isPSAStr == "是"

            let gradingCompany: String
            if let col = columnMap["评级公司"], let val = fields[safe: col], !val.isEmpty {
                gradingCompany = val
            } else {
                gradingCompany = isPSA ? GradingCompany.default.rawValue : GradingCompany.default.rawValue
            }

            let gradeStr: String
            if let col = columnMap["评级分数"], let val = fields[safe: col] {
                gradeStr = val
            } else if let col = columnMap["评级"], let val = fields[safe: col] {
                gradeStr = val
            } else {
                gradeStr = ""
            }

            let gradeDescriptionStr: String
            if let col = columnMap["评级描述"], let val = fields[safe: col] {
                gradeDescriptionStr = val
            } else {
                gradeDescriptionStr = ""
            }

            let popStr = fields[safe: columnMap["Pop"]] ?? ""
            let year = fields[safe: columnMap["年份"]]?.isEmpty == true ? nil : fields[safe: columnMap["年份"]]
            let variety = fields[safe: columnMap["变体"]]?.isEmpty == true ? nil : fields[safe: columnMap["变体"]]
            let purchaseDateStr = fields[safe: columnMap["购买日期"]] ?? ""
            let purchasePriceStr = fields[safe: columnMap["购买价格(¥)"]] ?? ""
            let sellDateStr = fields[safe: columnMap["出售日期"]] ?? ""
            let sellPriceStr = fields[safe: columnMap["出售价格(¥)"]] ?? ""
            let notes = fields[safe: columnMap["备注"]]?.isEmpty == true ? nil : fields[safe: columnMap["备注"]]
            let frontImagePath = fields[safe: columnMap["正面图片路径"]]?.isEmpty == true ? nil : fields[safe: columnMap["正面图片路径"]]
            let backImagePath = fields[safe: columnMap["背面图片路径"]]?.isEmpty == true ? nil : fields[safe: columnMap["背面图片路径"]]

            let grade = parseGrade(from: gradeStr)
            let population = Int(popStr)
            let purchasePrice = Double(purchasePriceStr)
            let sellPrice = Double(sellPriceStr)
            let purchaseDate = parseDate(from: purchaseDateStr)
            let sellDate = parseDate(from: sellDateStr)

            let gradeDescription: String? = gradeDescriptionStr.isEmpty ? nil : gradeDescriptionStr

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
                gradeDescription: gradeDescription,
                category: nil,
                labelType: nil,
                sortOrder: 0,
                gradingCompany: isPSA ? gradingCompany : GradingCompany.default.rawValue
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
                    askingPrice: nil,
                    language: CardLanguage.default.rawValue
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

    private static func buildColumnMap(header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, col) in header.enumerated() {
            let trimmed = col.trimmingCharacters(in: .whitespaces)
            map[trimmed] = index
        }
        return map
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

    private static func parseGrade(from str: String) -> String? {
        let gradeMap: [String: String] = [
            "GEM MT 10": "10", "MINT 9": "9", "NM-MT 8": "8", "NM 7": "7",
            "EXMT 6": "6", "EX 5": "5", "VG-EX 4": "4", "VG 3": "3",
            "GOOD 2": "2", "PR 1": "1"
        ]
        if let g = gradeMap[str] { return g }
        if str.hasPrefix("PSA ") {
            let numStr = str.replacingOccurrences(of: "PSA ", with: "")
            if Int(numStr) != nil { return numStr }
        }
        if Int(str) != nil { return str }
        if !str.isEmpty { return str }
        return nil
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
    subscript(safe index: Int?) -> Element? {
        guard let index else { return nil }
        return indices.contains(index) ? self[index] : nil
    }
}
