import SwiftData
import SwiftUI
import UIKit
import Foundation

@main
struct BoberHouseApp: App {
    private let container: ModelContainer
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if #available(iOS 15, *) {
            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithTransparentBackground()
            tabAppearance.backgroundEffect = nil
            tabAppearance.backgroundColor = .clear
            tabAppearance.shadowColor = .clear

            UITabBar.appearance().standardAppearance = tabAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
            UITabBar.appearance().backgroundImage = UIImage()
            UITabBar.appearance().shadowImage = UIImage()
            UITabBar.appearance().isTranslucent = true

            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithTransparentBackground()
            navAppearance.backgroundEffect = nil
            navAppearance.backgroundColor = .clear
            navAppearance.shadowColor = .clear

            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            UINavigationBar.appearance().compactAppearance = navAppearance
        }

        let schema = Schema([
            HouseholdMember.self,
            TaskTemplate.self,
            TaskOccurrence.self,
            CompletionEvent.self
        ])

        let storeURL = URL.applicationSupportDirectory.appendingPathComponent("default.store")
        let configuration = ModelConfiguration(url: storeURL)
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            do {
                try Self.resetStore(at: storeURL)
                container = try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("Failed to create SwiftData container: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

private extension BoberHouseApp {
    static func resetStore(at url: URL) throws {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
