// 缩放：⌘+ 放大、⌘- 缩小、⌘0 恢复 100%。
// 选中了图片：调这张图片的大小（宽度写进 ![说明|300](路径)）。
// 笔记：所有笔记窗口一起缩放，比例记住，下次打开还是这个大小。
// PDF：只缩放当前这个 PDF（用 PDF 自己的缩放）。
import SwiftUI
import PDFKit

@Observable
final class EditorZoom {
    static let shared = EditorZoom()
    private static let key = "editorZoom"
    /// 可以选的比例（和 Safari 差不多）
    static let steps: [Double] = [0.5, 0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    var scale: Double { didSet { UserDefaults.standard.set(scale, forKey: Self.key) } }

    private init() {
        let saved = UserDefaults.standard.double(forKey: Self.key)
        scale = Self.steps.contains(saved) ? saved : 1.0
    }

    func zoomIn() { scale = Self.steps.first { $0 > scale + 0.001 } ?? scale }
    func zoomOut() { scale = Self.steps.last { $0 < scale - 0.001 } ?? scale }
    func reset() { scale = 1.0 }

    /// 比例不是 100% 时显示在状态栏，比如“120%”
    var label: String? { abs(scale - 1) < 0.001 ? nil : "\(Int((scale * 100).rounded()))%" }
}

/// 菜单栏“显示”里的缩放：当前窗口是 PDF 就缩放 PDF，否则缩放笔记
struct ZoomCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()
            Button(L("放大", "Zoom In")) { zoom(.in) }
                .keyboardShortcut("=", modifiers: .command)
            Button(L("缩小", "Zoom Out")) { zoom(.out) }
                .keyboardShortcut("-", modifiers: .command)
            Button(L("实际大小", "Actual Size")) { zoom(.reset) }
                .keyboardShortcut("0", modifiers: .command)
        }
    }

    private enum Direction { case `in`, out, reset }

    private func zoom(_ direction: Direction) {
        // 笔记里选中了图片：调图片大小
        if let doc = OpenNotes.document(in: NSApp.keyWindow), doc.format.imageSelected {
            switch direction {
            case .in: doc.command("imageSize", "in")
            case .out: doc.command("imageSize", "out")
            case .reset: doc.command("imageSize", "reset")
            }
            return
        }
        if let pdf = NSApp.keyWindow?.contentView.flatMap(Self.findPDFView) {
            switch direction {
            case .in: pdf.zoomIn(nil)
            case .out: pdf.zoomOut(nil)
            case .reset: pdf.autoScales = true // 恢复成“适合窗口宽度”
            }
            return
        }
        let zoom = EditorZoom.shared
        switch direction {
        case .in: zoom.zoomIn()
        case .out: zoom.zoomOut()
        case .reset: zoom.reset()
        }
    }

    /// 在窗口里找 PDF 视图
    private static func findPDFView(in view: NSView) -> PDFView? {
        if let pdf = view as? PDFView { return pdf }
        for sub in view.subviews { if let found = findPDFView(in: sub) { return found } }
        return nil
    }
}
