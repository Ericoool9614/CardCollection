import SwiftUI

@main
struct CardCollectionApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .tint(.orange)
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.pie.fill")
            }
            .tag(0)

            NavigationStack {
                CardListView()
            }
            .tabItem {
                Label("Cards", systemImage: "rectangle.on.rectangle.angled")
            }
            .tag(1)
        }
        .tint(.orange)
    }
}
