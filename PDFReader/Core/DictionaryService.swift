import Foundation

// MARK: - API Response Models

struct WiktionaryResponse: Decodable {
    let word: String
    let entries: [WiktionaryEntry]
    let source: WiktionarySource?
}

struct WiktionaryEntry: Decodable {
    let language: WiktionaryLanguage
    let partOfSpeech: String
    let pronunciations: [WiktionaryPronunciation]?
    let senses: [WiktionarySense]
    let synonyms: [String]?
}

struct WiktionaryLanguage: Decodable {
    let code: String
    let name: String
}

struct WiktionaryPronunciation: Decodable {
    let type: String?
    let text: String?
}

struct WiktionarySense: Decodable {
    let definition: String
    let examples: [String]?
    let synonyms: [String]?
}

struct WiktionarySource: Decodable {
    let url: String?
}

// MARK: - App-level models (used by UI)

struct DictionaryResponse {
    let word: String
    let meanings: [Meaning]
    let primaryPhonetic: String?
}

struct Meaning {
    let partOfSpeech: String
    let definitions: [Definition]
    let allSynonyms: [String]

    var primaryDefinition: Definition? { definitions.first }
}

struct Definition {
    let definition: String
    let example: String?
    let synonyms: [String]
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

    private static let baseURL = "https://freedictionaryapi.com/api/v1/entries"

    /// Looks up a word. Tries English first, then French.
    static func define(word: String) async throws -> DictionaryResponse {
        let cleaned = cleanWord(word)
        guard !cleaned.isEmpty else {
            throw DictionaryError.wordNotFound
        }

        var lastError: DictionaryError = .wordNotFound

        for langCode in ["en", "fr"] {
            do {
                let result = try await fetch(word: cleaned, langCode: langCode)
                return result
            } catch let error as DictionaryError {
                switch error {
                case .noInternet:
                    throw error
                case .wordNotFound, .unknown:
                    lastError = error
                }
            }
        }

        throw lastError
    }

    // MARK: - Fetch

    private static func fetch(word: String, langCode: String) async throws -> DictionaryResponse {
        // URLComponents handles accented characters (é, è, à, ç, etc.) correctly
        var components = URLComponents()
        components.scheme = "https"
        components.host = "freedictionaryapi.com"
        components.path = "/api/v1/entries/\(langCode)/\(word)"

        guard let url = components.url else {
            throw DictionaryError.wordNotFound
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let http = response as? HTTPURLResponse else {
                throw DictionaryError.wordNotFound
            }

            if http.statusCode == 404 || http.statusCode == 400 {
                throw DictionaryError.wordNotFound
            }

            if http.statusCode == 429 {
                throw DictionaryError.unknown("Rate limit reached. Try again in a moment.")
            }

            let raw = try JSONDecoder().decode(WiktionaryResponse.self, from: data)
            return convert(raw)

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

    // MARK: - Convert API response → app model

    private static func convert(_ raw: WiktionaryResponse) -> DictionaryResponse {
        // Primary phonetic from first entry that has one
        let phonetic = raw.entries
            .compactMap { $0.pronunciations }
            .flatMap { $0 }
            .first(where: { $0.text != nil && !(($0.text ?? "").isEmpty) })?
            .text

        // Group entries by partOfSpeech into Meaning objects
        let meanings: [Meaning] = raw.entries.map { entry in
            let definitions = entry.senses.map { sense in
                Definition(
                    definition: sense.definition,
                    example: sense.examples?.first,
                    synonyms: sense.synonyms ?? []
                )
            }

            // Collect synonyms from both entry level and sense level
            let senseSynonyms = entry.senses.flatMap { $0.synonyms ?? [] }
            let entrySynonyms = entry.synonyms ?? []
            let allSyns = Array(Set(senseSynonyms + entrySynonyms))
                .sorted()
                .prefix(8)
                .map { $0 }

            return Meaning(
                partOfSpeech: entry.partOfSpeech,
                definitions: definitions,
                allSynonyms: allSyns
            )
        }

        return DictionaryResponse(
            word: raw.word,
            meanings: meanings,
            primaryPhonetic: phonetic
        )
    }

    // MARK: - Word cleaning

    private static func cleanWord(_ raw: String) -> String {
        let unicodeSpaces = CharacterSet(charactersIn:
            "\u{00A0}\u{202F}\u{2009}\u{200B}\u{FEFF}\u{2060}"
        )
        let allWhitespace = CharacterSet.whitespacesAndNewlines.union(unicodeSpaces)

        var result = raw.trimmingCharacters(in: allWhitespace)

        result = result.unicodeScalars
            .filter { !allWhitespace.contains($0) }
            .map { String($0) }
            .joined()

        result = result.components(separatedBy: .punctuationCharacters).joined()
        result = result.lowercased()

        return result
    }
}

// MARK: - Identifiable conformances for SwiftUI

extension Meaning: Identifiable {
    var id: String { partOfSpeech }
}

extension Definition: Identifiable {
    var id: String { definition }
}
