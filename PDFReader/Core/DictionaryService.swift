import Foundation

// MARK: - API Models

struct DictionaryResponse: Decodable {
    let word: String
    let meanings: [Meaning]
    let phonetics: [Phonetic]

    var primaryPhonetic: String? {
        phonetics.first(where: { $0.text != nil })?.text
    }
}

struct Phonetic: Decodable {
    let text: String?
}

struct Meaning: Decodable {
    let partOfSpeech: String
    let definitions: [Definition]
    let synonyms: [String]

    var primaryDefinition: Definition? { definitions.first }

    var allSynonyms: [String] {
        let fromDefinitions = definitions.flatMap { $0.synonyms }
        return Array(Set(synonyms + fromDefinitions)).sorted().prefix(8).map { $0 }
    }
}

struct Definition: Decodable {
    let definition: String
    let example: String?
    let synonyms: [String]
}

// MARK: - Supported languages

enum DictionaryLanguage: String {
    case english = "en"
    case french  = "fr"

    var apiCode: String { rawValue }
}

// MARK: - Errors

enum DictionaryError: LocalizedError {
    case wordNotFound
    case noInternet
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .wordNotFound: return "No definition found"
        case .noInternet:   return "No internet connection"
        case .unknown:      return "Something went wrong"
        }
    }

    var suggestion: String {
        switch self {
        case .wordNotFound: return "Try selecting a different word."
        case .noInternet:   return "Check your connection and try again."
        case .unknown:      return "Please try again."
        }
    }
}

// MARK: - Service

struct DictionaryService {

    private static let baseURL = "https://api.dictionaryapi.dev/api/v2/entries/"

    /// Looks up a word by trying English first, then French.
    /// Returns the first successful result, or throws if both fail.
    static func define(word: String) async throws -> DictionaryResponse {
        let cleaned = word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .punctuationCharacters)
            .joined()
            .lowercased()

        guard !cleaned.isEmpty else {
            throw DictionaryError.wordNotFound
        }

        // Try English, then French
        let languagesToTry: [DictionaryLanguage] = [.english, .french]

        var lastError: DictionaryError = .wordNotFound

        for language in languagesToTry {
            do {
                let result = try await fetch(word: cleaned, language: language)
                return result
            } catch let error as DictionaryError {
                switch error {
                case .noInternet:
                    // No point trying the next language
                    throw error
                case .wordNotFound, .unknown:
                    // Try the next language
                    lastError = error
                }
            }
        }

        throw lastError
    }

    // MARK: - Private

    private static func fetch(
        word: String,
        language: DictionaryLanguage
    ) async throws -> DictionaryResponse {

        guard
            let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: baseURL + language.apiCode + "/" + encoded)
        else {
            throw DictionaryError.wordNotFound
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                throw DictionaryError.wordNotFound
            }

            let decoded = try JSONDecoder().decode([DictionaryResponse].self, from: data)

            guard let first = decoded.first else {
                throw DictionaryError.wordNotFound
            }

            return first

        } catch let error as DictionaryError {
            throw error
        } catch let urlError as URLError {
            if urlError.code == .notConnectedToInternet ||
               urlError.code == .networkConnectionLost {
                throw DictionaryError.noInternet
            }
            throw DictionaryError.unknown(urlError.localizedDescription)
        } catch {
            throw DictionaryError.wordNotFound
        }
    }
}
