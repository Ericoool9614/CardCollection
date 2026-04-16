import Foundation

struct PSACertResponse: Codable, Sendable {
    let PSACert: PSACert

    struct PSACert: Codable, Sendable {
        let CertNumber: String
        let SpecID: Int
        let SpecNumber: String
        let LabelType: String
        let Year: String
        let Brand: String
        let Category: String
        let CardNumber: String
        let Subject: String
        let Variety: String
        let GradeDescription: String
        let CardGrade: String
        let TotalPopulation: Int
        let PopulationHigher: Int
    }
}

struct PSAImageItem: Codable, Sendable {
    let IsFrontImage: Bool
    let ImageURL: String
}

enum PSAServiceError: LocalizedError, Sendable {
    case invalidCertNumber
    case networkError(String)
    case parsingError(String)
    case notFound
    case imageDownloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidCertNumber:
            return "Invalid PSA certificate number"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .parsingError(let detail):
            return "Parse error: \(detail)"
        case .notFound:
            return "PSA card not found"
        case .imageDownloadFailed:
            return "Failed to download PSA images"
        }
    }
}

actor PSAService {
    static let shared = PSAService()

    private let baseURL = "https://api.psacard.com/publicapi/cert"
    private let authToken = "Bearer vYiX8b4LmhbeKLAeEpYcf7yT7nZ6BIU7oYxkmcvd99itUW2NOE367yow1DTnDOqNHlJw1iR6JDtnwyhMRZdjpFg30NHqf-6RIWIwtucZMrjzd4PIELexSy1sMwvuq5iuDt1Q9h9xYXfByutq8c6wtaWzKU3XC46amKbNUILev31fh_ezZAMCdViaypBVpRoS-534YYunwYQXYvXDc3tgyUqNY4VE4-QV-5KUVa3XsMUYBs7vM-X4CHyc6iUd5Uw7PdnMwL6j6cth5eR-BGZSBhAGwEnxgSdWlr6b7TOkPRBt2nq8"

    func fetchCard(certNumber: String) async throws -> PSACardResult {
        guard !certNumber.isEmpty else {
            throw PSAServiceError.invalidCertNumber
        }

        let certData = try await fetchCertData(certNumber: certNumber)
        let images = try await fetchImages(certNumber: certNumber)

        var frontLocalPath: String?
        var backLocalPath: String?

        for image in images {
            if image.IsFrontImage {
                frontLocalPath = try? await ImageStorageService.shared.downloadAndSave(
                    url: image.ImageURL,
                    certNumber: certNumber,
                    suffix: "front"
                )
            } else {
                backLocalPath = try? await ImageStorageService.shared.downloadAndSave(
                    url: image.ImageURL,
                    certNumber: certNumber,
                    suffix: "back"
                )
            }
        }

        let cert = certData.PSACert
        let grade = parseGrade(from: cert.CardGrade)

        return PSACardResult(
            certNumber: cert.CertNumber,
            grade: grade,
            population: cert.TotalPopulation,
            populationHigher: cert.PopulationHigher,
            frontImagePath: frontLocalPath,
            backImagePath: backLocalPath,
            cardName: cert.Subject,
            cardSet: cert.Brand,
            cardNumber: cert.CardNumber,
            year: cert.Year,
            variety: cert.Variety,
            gradeDescription: cert.GradeDescription,
            category: cert.Category,
            labelType: cert.LabelType
        )
    }

    private func fetchCertData(certNumber: String) async throws -> PSACertResponse {
        let urlString = "\(baseURL)/GetByCertNumber/\(certNumber)"
        guard let url = URL(string: urlString) else {
            throw PSAServiceError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("PSA API network error: \(error.localizedDescription)")
            throw PSAServiceError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PSAServiceError.networkError("Invalid response type")
        }

        print("PSA API response status: \(httpResponse.statusCode)")
        print("PSA API response body: \(String(data: data, encoding: .utf8) ?? "nil")")

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw PSAServiceError.notFound
            }
            throw PSAServiceError.networkError("HTTP \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(PSACertResponse.self, from: data)
        } catch {
            print("PSA API decode error: \(error)")
            throw PSAServiceError.parsingError(error.localizedDescription)
        }
    }

    private func fetchImages(certNumber: String) async throws -> [PSAImageItem] {
        let urlString = "\(baseURL)/GetImagesByCertNumber/\(certNumber)"
        guard let url = URL(string: urlString) else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return []
            }
            return try JSONDecoder().decode([PSAImageItem].self, from: data)
        } catch {
            print("PSA Images fetch error: \(error.localizedDescription)")
            return []
        }
    }

    private func parseGrade(from gradeString: String) -> Int {
        let gradeMap: [String: Int] = [
            "PR 1": 1, "FR 1.5": 2, "GOOD 2": 2, "GOOD 2.5": 2,
            "VG 3": 3, "VG 3.5": 3, "VG-EX 4": 4, "VG-EX 4.5": 4,
            "EX 5": 5, "EX 5.5": 5, "EXMT 6": 6, "NM 7": 7,
            "NM 7.5": 7, "NM-MT 8": 8, "MINT 9": 9, "GEM MT 10": 10
        ]
        if let grade = gradeMap[gradeString] {
            return grade
        }
        if let number = gradeString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().first.flatMap({ Int(String($0)) }) {
            return number
        }
        return 0
    }
}

struct PSACardResult: Sendable {
    let certNumber: String
    let grade: Int
    let population: Int
    let populationHigher: Int
    let frontImagePath: String?
    let backImagePath: String?
    let cardName: String
    let cardSet: String
    let cardNumber: String
    let year: String
    let variety: String
    let gradeDescription: String
    let category: String
    let labelType: String
}
