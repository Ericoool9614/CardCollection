import Foundation
import Combine

@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @Published var hidePrices: Bool {
        didSet { UserDefaults.standard.set(hidePrices, forKey: "hidePrices") }
    }

    private init() {
        self.hidePrices = UserDefaults.standard.bool(forKey: "hidePrices")
    }
}
