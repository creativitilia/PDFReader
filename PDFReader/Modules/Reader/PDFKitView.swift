import SwiftUI
import PDFKit
import UIKit

// MARK: - PDFKitView

struct PDFKitView: UIViewRepresentable {

    let document: PDFDocument
    let currentPageIndex: Int
    var onPageChanged: (Int) -> Void
    var onSelectionChanged: (PDFSelection?) -> Void
    var onTap: (CGPoint, PDFView) -> Void
    var onHighlightRequested: (PDFSelection, CGPoint) -> Void
    var onAddNoteRequested: (PDFSelection) -> Void
    var onDefineRequested: (String) -> Void

    func makeUIView(context: Context) -> ReaderPDFView {
        let pdfView = ReaderPDFView()
        pdfView.displayMode        = .singlePageContinuous
        pdfView.displayDirection   = .vertical
        pdfView.usePageViewController(false)
        pdfView.autoScales         = true
        pdfView.backgroundColor    = UIColor.systemBackground
        pdfView.pageShadowsEnabled = false
        pdfView.document           = document
        pdfView.isUserInteractionEnabled = true
        pdfView.menuDelegate       = context.coordinator

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
        var onHighlightRequested: (PDFSelection, CGPoint) -> Void
        var onAddNoteRequested: (PDFSelection) -> Void
        var onDefineRequested: (String) -> Void
        weak var pdfView: ReaderPDFView?

        init(
            onPageChanged: @escaping (Int) -> Void,
            onSelectionChanged: @escaping (PDFSelection?) -> Void,
            onTap: @escaping (CGPoint, PDFView) -> Void,
            onHighlightRequested: @escaping (PDFSelection, CGPoint) -> Void,
            onAddNoteRequested: @escaping (PDFSelection) -> Void,
            onDefineRequested: @escaping (String) -> Void
        ) {
            self.onPageChanged        = onPageChanged
            self.onSelectionChanged   = onSelectionChanged
            self.onTap                = onTap
            self.onHighlightRequested = onHighlightRequested
            self.onAddNoteRequested   = onAddNoteRequested
            self.onDefineRequested    = onDefineRequested
        }

        @objc func pageDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let page    = pdfView.currentPage,
                  let doc     = pdfView.document
            else { return }
            let index = doc.index(for: page)
            DispatchQueue.main.async { self.onPageChanged(index) }
        }

        // selectionDidChange fires continuously while dragging.
        // We only report the selection upward — we do NOT present
        // the menu here. The menu is shown in touchesEnded instead.
        @objc func selectionDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            DispatchQueue.main.async {
                self.onSelectionChanged(pdfView.currentSelection)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView else { return }
            let point = gesture.location(in: pdfView)
            DispatchQueue.main.async { self.onTap(point, pdfView) }
        }

        // MARK: ReaderPDFViewMenuDelegate

        func readerPDFViewDidRequestHighlight(_ pdfView: ReaderPDFView,
                                              selection: PDFSelection,
                                              screenPoint: CGPoint) {
            DispatchQueue.main.async {
                self.onHighlightRequested(selection, screenPoint)
            }
        }

        func readerPDFViewDidRequestAddNote(_ pdfView: ReaderPDFView,
                                            selection: PDFSelection) {
            DispatchQueue.main.async { self.onAddNoteRequested(selection) }
        }

        func readerPDFViewDidRequestDefine(_ pdfView: ReaderPDFView, text: String) {
            DispatchQueue.main.async { self.onDefineRequested(text) }
        }
    }
}

// MARK: - Delegate protocol

protocol ReaderPDFViewMenuDelegate: AnyObject {
    func readerPDFViewDidRequestHighlight(_ pdfView: ReaderPDFView,
                                          selection: PDFSelection,
                                          screenPoint: CGPoint)
    func readerPDFViewDidRequestAddNote(_ pdfView: ReaderPDFView,
                                        selection: PDFSelection)
    func readerPDFViewDidRequestDefine(_ pdfView: ReaderPDFView, text: String)
}

// MARK: - ReaderPDFView

final class ReaderPDFView: PDFView, UIEditMenuInteractionDelegate {

    weak var menuDelegate: ReaderPDFViewMenuDelegate?

    private lazy var editMenuInteraction = UIEditMenuInteraction(delegate: self)

    // Tracks whether a finger is currently down — used to defer
    // menu presentation until the user lifts their finger.
    private var isTouchActive = false

    override var canBecomeFirstResponder: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addInteraction(editMenuInteraction)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addInteraction(editMenuInteraction)
    }

    // MARK: - Touch tracking

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouchActive = true
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouchActive = false
        super.touchesEnded(touches, with: event)
        // Present our menu once the finger lifts, if there is a selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.showCustomMenuIfNeeded()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouchActive = false
        super.touchesCancelled(touches, with: event)
    }

    // MARK: - Show menu

    /// Only presents the menu when the touch is no longer active
    /// (finger lifted), ensuring it appears after the selection is final.
    func showCustomMenuIfNeeded() {
        guard !isTouchActive, hasSelection else { return }
        guard let point = menuAnchorPoint else { return }
        becomeFirstResponder()
        let config = UIEditMenuConfiguration(identifier: nil, sourcePoint: point)
        editMenuInteraction.presentEditMenu(with: config)
    }

    // MARK: - UIEditMenuInteractionDelegate

    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        guard hasSelection else { return nil }

        // Extract only Copy from system suggestions
        let systemCopy = suggestedActions
            .compactMap { $0 as? UIAction }
            .first { $0.identifier.rawValue.lowercased().contains("copy") }

        var items: [UIMenuElement] = []

        if let copy = systemCopy {
            items.append(copy)
        }

        items.append(UIAction(
            title: "Highlight",
            image: UIImage(systemName: "highlighter")
        ) { [weak self] _ in
            self?.handleHighlight()
        })

        items.append(UIAction(
            title: "Add Note",
            image: UIImage(systemName: "note.text")
        ) { [weak self] _ in
            self?.handleAddNote()
        })

        // Define only for single words
        if isSingleWord {
            items.append(UIAction(
                title: "Define",
                image: UIImage(systemName: "character.book.closed")
            ) { [weak self] _ in
                self?.handleDefine()
            })
        }

        return UIMenu(children: items)
    }

    // MARK: - canPerformAction
    // Suppress the system menu items so only our menu shows

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Block all system extras
        let blocked: [Selector] = [
            Selector(("lookup:")),
            Selector(("_lookup:")),
            Selector(("_define:")),
            Selector(("translate:")),
            Selector(("_translate:")),
            Selector(("share:")),
            Selector(("_share:")),
            Selector(("_showTextStyleOptions:")),
        ]
        if blocked.contains(action) { return false }

        // Allow copy/paste natively
        if action == #selector(copy(_:)) || action == #selector(paste(_:)) {
            return super.canPerformAction(action, withSender: sender)
        }

        return false
    }

    // MARK: - Action handlers

    private func handleHighlight() {
        guard let selection = copiedSelection() else { return }
        let point = menuAnchorPoint ?? .zero
        let screenPoint: CGPoint
        if let window = self.window {
            screenPoint = convert(point, to: window)
        } else {
            screenPoint = point
        }
        menuDelegate?.readerPDFViewDidRequestHighlight(
            self, selection: selection, screenPoint: screenPoint
        )
    }

    private func handleAddNote() {
        guard let selection = copiedSelection() else { return }
        menuDelegate?.readerPDFViewDidRequestAddNote(self, selection: selection)
    }

    private func handleDefine() {
        guard let text = trimmedText, !text.isEmpty else { return }
        menuDelegate?.readerPDFViewDidRequestDefine(self, text: text)
    }

    // MARK: - Helpers

    private var hasSelection: Bool {
        copiedSelection() != nil
    }

    private var trimmedText: String? {
        currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSingleWord: Bool {
        guard let text = trimmedText, !text.isEmpty else { return false }
        let unicodeSpaces = CharacterSet(charactersIn: "\u{00A0}\u{202F}\u{2009}\u{200B}")
        let allSpaces = CharacterSet.whitespacesAndNewlines.union(unicodeSpaces)
        return !text.unicodeScalars.contains { allSpaces.contains($0) }
    }

    private var menuAnchorPoint: CGPoint? {
        guard let selection = currentSelection,
              let page = selection.pages.first
        else { return nil }
        let bounds = selection.bounds(for: page)
        return convert(CGPoint(x: bounds.midX, y: bounds.maxY), from: page)
    }

    private func copiedSelection() -> PDFSelection? {
        guard let s = currentSelection,
              !(s.string ?? "").isEmpty
        else { return nil }
        return s.copy() as? PDFSelection
    }
}
