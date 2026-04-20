import SwiftUI

enum DefinitionState {
    case idle
    case loading
    case loaded(DictionaryResponse)
    case error(DictionaryError)
}

@Observable
final class DefinitionViewModel {

    var state: DefinitionState = .idle
    var activeTab: Int = 0          // 0 = definition, 1 = synonyms
    private var currentTask: Task<Void, Never>?

    var isVisible: Bool {
        switch state {
        case .idle: return false
        default:    return true
        }
    }

    func lookup(word: String) {
        currentTask?.cancel()
        activeTab = 0
        state = .loading

        currentTask = Task {
            do {
                let result = try await DictionaryService.define(word: word)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.state = .loaded(result)
                }
            } catch let error as DictionaryError {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.state = .error(error)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.state = .error(.unknown(error.localizedDescription))
                }
            }
        }
    }

    func dismiss() {
        currentTask?.cancel()
        state = .idle
        activeTab = 0
    }
}
