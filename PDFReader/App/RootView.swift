import SwiftUI
import SwiftData

/// The app's root navigation container.
/// Hosts a NavigationStack so any screen can push onto the stack.
struct RootView: View {
    var body: some View {
        NavigationStack {
            LibraryView()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(AppContainer.shared.modelContainer)
}
