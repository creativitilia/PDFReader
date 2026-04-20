import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {

    let document: PDFDocument
    let currentPageIndex: Int
    var onPageChanged: (Int) -> Void
    var onSelectionChanged: (PDFSelection?) -> Void
    var onTap: (CGPoint, PDFView) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()

        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.autoScales = true
        pdfView.backgroundColor = UIColor.systemBackground
        pdfView.pageShadowsEnabled = false
        pdfView.document = document
        pdfView.isUserInteractionEnabled = true

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

    func updateUIView(_ pdfView: PDFView, context: Context) {
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
            onTap: onTap
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var onPageChanged: (Int) -> Void
        var onSelectionChanged: (PDFSelection?) -> Void
        var onTap: (CGPoint, PDFView) -> Void
        weak var pdfView: PDFView?

        init(
            onPageChanged: @escaping (Int) -> Void,
            onSelectionChanged: @escaping (PDFSelection?) -> Void,
            onTap: @escaping (CGPoint, PDFView) -> Void
        ) {
            self.onPageChanged = onPageChanged
            self.onSelectionChanged = onSelectionChanged
            self.onTap = onTap
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
            guard let pdfView = notification.object as? PDFView else { return }
            DispatchQueue.main.async {
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
    }
}
