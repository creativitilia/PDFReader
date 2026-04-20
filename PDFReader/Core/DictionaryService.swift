import Foundation

// MARK: - Raw API models
// All fields match the API schema exactly — nothing is optional
// except fields the API truly omits in some responses.

private struct APIResponse: Decodable {
    let word: String
    let entries: [APIEntry]
}

private struct APIEntry: Decodable {
    let language: APILanguage
    let partOfSpeech: String
    let pronunciations: [APIPronunciation]
    let senses: [APISense]
    let synonyms: [String]
    let antonyms: [String]

    enum CodingKeys: String, CodingKey {
        case language, partOfSpeech, pronunciations, senses, synonyms, antonyms
    }
}

private struct APILanguage: Decodable {
    let code: String
    let name: String
}

private struct APIPronunciation: Decodable {
    let type: String
    let text: String
    let tags: [String]

    // Some pronunciations omit type/text in edge cases — make safe
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
    }
    enum CodingKeys: String, CodingKey { case type, text, tags }
}

private struct APISense: Decodable {
    let definition: String
    let examples: [String]
    let synonyms: [String]
    let antonyms: [String]
    // subsenses is recursive — we decode it but don't use it deeply
    let subsenses: [APISense]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        definition = (try? c.decode(String.self, forKey: .definition)) ?? ""
        examples   = (try? c.decode([String].self, forKey: .examples))  ?? []
        synonyms   = (try? c.decode([String].self, forKey: .synonyms))  ?? []
        antonyms   = (try? c.decode([String].self, forKey: .antonyms))  ?? []
        subsenses  = (try? c.decode([APISense].self, forKey: .subsenses)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case definition, examples, synonyms, antonyms, subsenses
    }
}

// MARK: - App-level models (consumed by UI)

struct DictionaryResponse {
    let word: String
    let phonetic: String?
    let entries: [DictionaryEntry]
}

struct DictionaryEntry {
    let partOfSpeech: String
    let definitions: [DictionaryDefinition]
    let synonyms: [String]
}

struct DictionaryDefinition {
    let text: String
    let example: String?
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

    private static let base = "https://freedictionaryapi.com/api/v1/entries"

    /// Tries English first, then French. Returns first success.
    static func define(word: String) async throws -> DictionaryResponse {
        let cleaned = clean(word)
        guard !cleaned.isEmpty else { throw DictionaryError.wordNotFound }

        var last: DictionaryError = .wordNotFound
        for lang in ["en", "fr"] {
            do {
                return try await fetch(word: cleaned, lang: lang)
            } catch let e as DictionaryError {
                if case .noInternet = e { throw e }
                last = e
            }
        }
        throw last
    }

    // MARK: - Fetch

    private static func fetch(word: String, lang: String) async throws -> DictionaryResponse {
        var components = URLComponents()
        components.scheme = "https"
        components.host   = "freedictionaryapi.com"
        components.path   = "/api/v1/entries/\(lang)/\(word)"

        guard let url = components.url else { throw DictionaryError.wordNotFound }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw DictionaryError.wordNotFound }

            switch http.statusCode {
            case 200:       break
            case 400, 404:  throw DictionaryError.wordNotFound
            case 429:       throw DictionaryError.unknown("Rate limit reached. Try again shortly.")
            default:        throw DictionaryError.unknown("Server error \(http.statusCode).")
            }

            let raw = try JSONDecoder().decode(APIResponse.self, from: data)
            guard !raw.entries.isEmpty else { throw DictionaryError.wordNotFound }
            return convert(raw)

        } catch let e as DictionaryError { throw e
        } catch let e as URLError {
            throw (e.code == .notConnectedToInternet || e.code == .networkConnectionLost)
                ? DictionaryError.noInternet
                : DictionaryError.unknown(e.localizedDescription)
        } catch {
            throw DictionaryError.wordNotFound
        }
    }

    // MARK: - Convert

    private static func convert(_ raw: APIResponse) -> DictionaryResponse {
        let phonetic = raw.entries
            .flatMap { $0.pronunciations }
            .first { !$0.text.isEmpty }?
            .text

        let entries = raw.entries.map { entry -> DictionaryEntry in
            let defs = entry.senses.map { sense -> DictionaryDefinition in
                DictionaryDefinition(
                    text: sense.definition,
                    example: sense.examples.first
                )
            }

            // Collect synonyms from entry level + all senses
            let allSyns = Array(Set(
                entry.synonyms + entry.senses.flatMap { $0.synonyms }
            ))
            .filter { !$0.isEmpty }
            .sorted()
            .prefix(10)
            .map { $0 }

            return DictionaryEntry(
                partOfSpeech: entry.partOfSpeech,
                definitions: defs,
                synonyms: allSyns
            )
        }

        return DictionaryResponse(word: raw.word, phonetic: phonetic, entries: entries)
    }

    // MARK: - Clean

    private static func clean(_ raw: String) -> String {
        let spaces = CharacterSet(charactersIn: "\u{00A0}\u{202F}\u{2009}\u{200B}\u{FEFF}\u{2060}")
        let all = CharacterSet.whitespacesAndNewlines.union(spaces)
        var s = raw.trimmingCharacters(in: all)
        s = s.unicodeScalars.filter { !all.contains($0) }.map { String($0) }.joined()
        s = s.components(separatedBy: .punctuationCharacters).joined()
        return s.lowercased()
    }
}
