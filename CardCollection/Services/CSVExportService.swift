import Foundation

struct CSVExportService {
    static func export(entries: [CardEntryItem]) -> URL? {
        var csv = "Nickname,Card Name,Set,Number,Is PSA,Grade,Population,Year,Variety,Purchase Date,Purchase Price,Sell Date,Sell Price,Profit,Notes\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        for entry in entries {
            for card in entry.subcards {
                let nickname = escapeCSV(entry.nickname ?? "")
                let name = escapeCSV(card.name)
                let set = escapeCSV(card.set ?? "")
                let number = escapeCSV(card.number ?? "")
                let isPSA = card.isPSA ? "Yes" : "No"
                let grade = card.gradeDescription ?? (card.grade.map { "PSA \($0)" } ?? "")
                let pop = card.population.map { "\($0)" } ?? ""
                let year = escapeCSV(card.year ?? "")
                let variety = escapeCSV(card.variety ?? "")
                let purchaseDate = entry.purchaseDate.map { dateFormatter.string(from: $0) } ?? ""
                let purchasePrice = entry.purchasePrice.map { String(format: "%.2f", $0) } ?? ""
                let sellDate = entry.sellDate.map { dateFormatter.string(from: $0) } ?? ""
                let sellPrice = entry.sellPrice.map { String(format: "%.2f", $0) } ?? ""
                let profit = entry.profit.map { String(format: "%.2f", $0) } ?? ""
                let notes = escapeCSV(entry.note ?? "")

                csv += "\(nickname),\(name),\(set),\(number),\(isPSA),\(grade),\(pop),\(year),\(variety),\(purchaseDate),\(purchasePrice),\(sellDate),\(sellPrice),\(profit),\(notes)\n"
            }
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "CardCollection_Export_\(formatDateForFilename(Date())).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: date)
    }
}
