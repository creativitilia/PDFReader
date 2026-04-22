import SwiftUI
import PDFKit
import UIKit

struct PDFKitView: UIViewRepresentable {

    let document: PDFDocument
    let currentPageIndex: Int
    var onPageChanged: (Int) -> Void
    var onSelectionChanged: (PDFSelection?) -> Void
    var onTap: (CGPoint, PDFView) -> Void
    var onHighlightRequested: (PDFSelection) -> Void
    var onAddNoteRequested: (PDFSelection) -> Void
    var onDefineRequested: (String) -> Void

    func makeUIView(context: Context) -> ReaderPDFView {
        let pdfView = ReaderPDFView()

        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.autoScales = true
        pdfView.backgroundColor = UIColor.systemBackground
        pdfView.pageShadowsEnabled = false
        pdfView.document = document
        pdfView.isUserInteractionEnabled = true
        pdfView.menuDelegate = context.coordinator

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageDidChange(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionDidChange(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        pdfView.addGestureRecognizer(tap)

        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateUIView(_ pdfView: ReaderPDFView, context: Context) {
        guard
            let page = document.page(at: currentPageIndex),
            pdfView.currentPage != page
        else { return }
        pdfView.go(to: page)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPageChanged: onPageChanged,
            onSelectionChanged: onSelectionChanged,
            onTap: onTap,
            onHighlightRequested: onHighlightRequested,
            onAddNoteRequested: onAddNoteRequested,
            onDefineRequested: onDefineRequested
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, ReaderPDFViewMenuDelegate {
        var onPageChanged: (Int) -> Void
        var onSelectionChanged: (PDFSelection?) -> Void
        var onTap: (CGPoint, PDFView) -> Void
        var onHighlightRequested: (PDFSelection) -> Void
        var onAddNoteRequested: (PDFSelection) -> Void
        var onDefineRequested: (String) -> Void
        weak var pdfView: ReaderPDFView?

        init(
            onPageChanged: @escaping (Int) -> Void,
            onSelectionChanged: @escaping (PDFSelection?) -> Void,
            onTap: @escaping (CGPoint, PDFView) -> Void,
            onHighlightRequested: @escaping (PDFSelection) -> Void,
            onAddNoteRequested: @escaping (PDFSelection) -> Void,
            onDefineRequested: @escaping (String) -> Void
        ) {
            self.onPageChanged = onPageChanged
            self.onSelectionChanged = onSelectionChanged
            self.onTap = onTap
            self.onHighlightRequested = onHighlightRequested
            self.onAddNoteRequested = onAddNoteRequested
            self.onDefineRequested = onDefineRequested
        }

        @objc func pageDidChange(_ notification: Notification) {
            guard
                let pdfView = notification.object as? PDFView,
                let page = pdfView.currentPage,
                let doc = pdfView.document
            else { return }
            let index = doc.index(for: page)
            DispatchQueue.main.async {
                self.onPageChanged(index)
            }
        }

        @objc func selectionDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? ReaderPDFView else { return }
            DispatchQueue.main.async {
                pdfView.refreshSelectionMenu()
                self.onSelectionChanged(pdfView.currentSelection)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView else { return }
            let point = gesture.location(in: pdfView)
            DispatchQueue.main.async {
                self.onTap(point, pdfView)
            }
        }

        func readerPDFViewDidRequestHighlight(_ pdfView: ReaderPDFView, selection: PDFSelection) {
            DispatchQueue.main.async {
                self.onHighlightRequested(selection)
            }
        }

        func readerPDFViewDidRequestAddNote(_ pdfView: ReaderPDFView, selection: PDFSelection) {
            DispatchQueue.main.async {
                self.onAddNoteRequested(selection)
            }
        }

        func readerPDFViewDidRequestDefine(_ pdfView: ReaderPDFView, text: String) {
            DispatchQueue.main.async {
                self.onDefineRequested(text)
            }
        }
    }
}

// MARK: - Protocol

protocol ReaderPDFViewMenuDelegate: AnyObject {
    func readerPDFViewDidRequestHighlight(_ pdfView: ReaderPDFView, selection: PDFSelection)
    func readerPDFViewDidRequestAddNote(_ pdfView: ReaderPDFView, selection: PDFSelection)
    func readerPDFViewDidRequestDefine(_ pdfView: ReaderPDFView, text: String)
}

// MARK: - ReaderPDFView

final class ReaderPDFView: PDFView, UIEditMenuInteractionDelegate {

    weak var menuDelegate: ReaderPDFViewMenuDelegate?

    private lazy var editMenuInteraction = UIEditMenuInteraction(delegate: self)

    override var canBecomeFirstResponder: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addInteraction(editMenuInteraction)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addInteraction(editMenuInteraction)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let hasSelection = copiedSelection() != nil

        switch action {
        case #selector(readerHighlight(_:)):
            return hasSelection
        case #selector(readerAddNote(_:)):
            return hasSelection
        case #selector(readerDefine(_:)):
            return isSingleWordSelection
        case Selector(("lookup:")),
             Selector(("_lookup:")),
             Selector(("_define:")):
            return false
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }

    func refreshSelectionMenu() {
        guard let point = menuSourcePoint else { return }
        becomeFirstResponder()
        let config = UIEditMenuConfiguration(identifier: nil, sourcePoint: point)
        editMenuInteraction.presentEditMenu(with: config)
    }

    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        var actions = suggestedActions

        let highlight = UIAction(title: "Highlight") { [weak self] _ in
            self?.readerHighlight(nil)
        }

        let addNote = UIAction(title: "Add Note") { [weak self] _ in
            self?.readerAddNote(nil)
        }

        actions.append(highlight)
        actions.append(addNote)

        if isSingleWordSelection {
            let define = UIAction(title: "Define") { [weak self] _ in
                self?.readerDefine(nil)
            }
            actions.append(define)
        }

        return UIMenu(children: actions)
    }

    @objc func readerHighlight(_ sender: Any?) {
        guard let selection = copiedSelection() else { return }
        menuDelegate?.readerPDFViewDidRequestHighlight(self, selection: selection)
    }

    @objc func readerAddNote(_ sender: Any?) {
        guard let selection = copiedSelection() else { return }
        menuDelegate?.readerPDFViewDidRequestAddNote(self, selection: selection)
    }

    @objc func readerDefine(_ sender: Any?) {
        guard let text = trimmedSelectedText, !text.isEmpty else { return }
        menuDelegate?.readerPDFViewDidRequestDefine(self, text: text)
    }

    // MARK: - Private helpers

    private var trimmedSelectedText: String? {
        currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSingleWordSelection: Bool {
        guard let text = trimmedSelectedText, !text.isEmpty else { return false }
        let unicodeSpaces = CharacterSet(charactersIn: "\u{00A0}\u{202F}\u{2009}\u{200B}")
        let allSpaces = CharacterSet.whitespacesAndNewlines.union(unicodeSpaces)
        return !text.unicodeScalars.contains { allSpaces.contains($0) }
    }

    private var menuSourcePoint: CGPoint? {
        guard
            let selection = currentSelection,
            let page = selection.pages.first
        else { return nil }
        let bounds = selection.bounds(for: page)
        let topMid = CGPoint(x: bounds.midX, y: bounds.maxY)
        return convert(topMid, from: page)
    }

    private func copiedSelection() -> PDFSelection? {
        guard let selection = currentSelection,
              !(selection.string ?? "").isEmpty
        else { return nil }
        return selection.copy() as? PDFSelection
    }
}
