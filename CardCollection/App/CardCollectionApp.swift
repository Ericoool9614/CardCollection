import SwiftUI

@main
struct CardCollectionApp: App {
    @StateObject private var persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    DashboardView()
                }
                .tabItem {
                    Label("概览", systemImage: "chart.pie.fill")
                }

                NavigationStack {
                    CardListView()
                }
                .tabItem {
                    Label("我的卡牌", systemImage: "rectangle.on.rectangle.angled")
                }
            }
            .environment(\.managedObjectContext, persistence.container.viewContext)
            .tint(.orange)
        }
    }
}
