import SwiftData
import Foundation
import UIKit
import SwiftUI

// MARK: - HighlightColor

enum HighlightColor: String, Codable, CaseIterable {
    case yellow, blue, green, pink, purple

    var uiColor: UIColor {
        switch self {
        case .yellow: return UIColor(red: 0.98, green: 0.82, blue: 0.25, alpha: 1)
        case .blue:   return UIColor(red: 0.38, green: 0.65, blue: 0.96, alpha: 1)
        case .green:  return UIColor(red: 0.21, green: 0.82, blue: 0.60, alpha: 1)
        case .pink:   return UIColor(red: 0.96, green: 0.45, blue: 0.63, alpha: 1)
        case .purple: return UIColor(red: 0.66, green: 0.55, blue: 0.98, alpha: 1)
        }
    }

    var color: Color {
        Color(uiColor)
    }
}

// MARK: - Highlight

@Model
final class Highlight {

    var id: UUID
    var documentID: UUID
    var pageIndex: Int
    var boundingBoxesData: Data
    var colorName: String
    var selectedText: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var note: Note?

    init(
        id: UUID = UUID(),
        documentID: UUID,
        pageIndex: Int,
        boundingBoxes: [CGRect],
        color: HighlightColor,
        selectedText: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.documentID = documentID
        self.pageIndex = pageIndex
        self.boundingBoxesData = (try? JSONEncoder().encode(
            boundingBoxes.map { CodableRect(rect: $0) }
        )) ?? Data()
        self.colorName = color.rawValue
        self.selectedText = selectedText
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var color: HighlightColor {
        HighlightColor(rawValue: colorName) ?? .yellow
    }

    var boundingBoxes: [CGRect] {
        let decoded = try? JSONDecoder().decode([CodableRect].self, from: boundingBoxesData)
        return decoded?.map(\.rect) ?? []
    }
}

// MARK: - Note

@Model
final class Note {

    var id: UUID
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), body: String, createdAt: Date = .now) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

// MARK: - Bookmark

@Model
final class Bookmark {

    var id: UUID
    var documentID: UUID
    var name: String
    var pageIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        documentID: UUID,
        name: String,
        pageIndex: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.documentID = documentID
        self.name = name
        self.pageIndex = pageIndex
        self.createdAt = createdAt
    }
}

// MARK: - CodableRect

struct CodableRect: Codable {
    let x, y, width, height: Double

    init(rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
