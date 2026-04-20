import SwiftUI
import SwiftData

@main
struct PDFReaderApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppContainer.shared.modelContainer)
    }
}
