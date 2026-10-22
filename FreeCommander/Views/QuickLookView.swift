import Quartz
import SwiftUI

/// Podgląd pliku w technologii Quick Look (ten sam silnik co spacja w Finderze).
struct QuickLookView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)
        view?.previewItem = url as NSURL
        view?.shouldCloseWithWindow = true
        return view ?? QLPreviewView()
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
    }
}
