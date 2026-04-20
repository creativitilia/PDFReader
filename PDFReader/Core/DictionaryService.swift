import Foundation
import NaturalLanguage

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

    /// The language code segment used in the API URL.
    var apiCode: String {
        switch self {
        case .english: return "en"
        case .french:  return "fr"
        }
    }
}

// MARK: - Errors

enum DictionaryError: LocalizedError {
    case wordNotFound(language: DictionaryLanguage)
    case unsupportedLanguage(detected: String)
    case noInternet
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .wordNotFound:             return "No definition found"
        case .unsupportedLanguage:      return "Language not supported"
        case .noInternet:               return "No internet connection"
        case .unknown(let msg):         return msg
        }
    }

    var suggestion: String {
        switch self {
        case .wordNotFound(let lang):
            switch lang {
            case .english: return "Try selecting a different English word."
            case .french:  return "Essayez de sélectionner un autre mot français."
            }
        case .unsupportedLanguage(let lang):
            return "Detected language: \(lang). Only English and French are supported."
        case .noInternet:
            return "Check your connection and try again."
        case .unknown:
            return "Please try again."
        }
    }
}

// MARK: - Service

struct DictionaryService {

    private static let baseURL = "https://api.dictionaryapi.dev/api/v2/entries/"

    static func define(word: String) async throws -> DictionaryResponse {
        let cleaned = word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .punctuationCharacters)
            .joined()
            .lowercased()

        guard !cleaned.isEmpty else {
            throw DictionaryError.wordNotFound(language: .english)
        }

        // Detect language using Apple's NaturalLanguage framework — no network needed
        let language = detectLanguage(for: cleaned)

        guard let lang = language else {
            throw DictionaryError.wordNotFound(language: .english)
        }

        guard let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURL + lang.apiCode + "/" + encoded)
        else {
            throw DictionaryError.wordNotFound(language: lang)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                throw DictionaryError.wordNotFound(language: lang)
            }

            let decoded = try JSONDecoder().decode([DictionaryResponse].self, from: data)

            guard let first = decoded.first else {
                throw DictionaryError.wordNotFound(language: lang)
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
            throw DictionaryError.wordNotFound(language: .english)
        }
    }

    // MARK: - Language detection

    /// Uses Apple's on-device NaturalLanguage framework to detect
    /// whether the word is English or French. Falls back to English
    /// if detection is inconclusive.
    private static func detectLanguage(for word: String) -> DictionaryLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(word)

        // Get the most likely language with its confidence
        guard let dominant = recognizer.dominantLanguage else {
            return .english
        }

        switch dominant {
        case .english:
            return .english
        case .french:
            return .french
        default:
            // For ambiguous single words, check hypotheses for English/French
            let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
            let enScore = hypotheses[.english] ?? 0
            let frScore = hypotheses[.french] ?? 0

            if frScore > enScore {
                return .french
            }
            return .english
        }
    }
}
