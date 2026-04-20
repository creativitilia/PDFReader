import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {

    let document: PDFDocument
    let currentPageIndex: Int
    var onPageChanged: (Int) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()

        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.autoScales = true
        pdfView.backgroundColor = UIColor.systemBackground
        pdfView.pageShadowsEnabled = false
        pdfView.document = document

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageDidChange(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

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
        Coordinator(onPageChanged: onPageChanged)
    }

    final class Coordinator: NSObject {
        var onPageChanged: (Int) -> Void

        init(onPageChanged: @escaping (Int) -> Void) {
            self.onPageChanged = onPageChanged
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
    }
}
