import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = HouseholdStore()

    var body: some View {
        ZStack {
            BackgroundGradient()

            TabView {
                DashboardView()
                    .tabItem {
                        Label("Today", systemImage: "sparkles")
                    }

                TaskListView()
                    .tabItem {
                        Label("Tasks", systemImage: "square.grid.2x2")
                    }

                TimelineView()
                    .tabItem {
                        Label("Timeline", systemImage: "clock")
                    }

                HouseholdSettingsView()
                    .tabItem {
                        Label("Household", systemImage: "person.2")
                    }
            }
            .background(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .toolbarBackground(.clear, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .environmentObject(store)
        .task {
            PushRegistrationManager.shared.attach(store: store)
            await store.attachIfNeeded(modelContext: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}

private struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.98),
                Color(red: 0.92, green: 0.94, blue: 0.99),
                Color(red: 0.16, green: 0.21, blue: 0.37),
                Color(red: 0.04, green: 0.06, blue: 0.13)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
