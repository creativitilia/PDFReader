import SwiftData
import Foundation

/// Central dependency container. Holds the SwiftData ModelContainer
/// and any app-wide singletons. Instantiated once at launch.
final class AppContainer {

    static let shared = AppContainer()

    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([
            Document.self,
            Highlight.self,
            Note.self,
            Bookmark.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }
}
