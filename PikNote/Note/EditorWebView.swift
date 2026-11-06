// 编辑器用的网页视图：自己接住从访达拖进来的图片。
// （嵌在软件里的网页不会把拖进来的文件交给编辑器，所以由 Mac 这边直接处理）
import AppKit
import WebKit
import UniformTypeIdentifiers

final class EditorWebView: WKWebView {
    /// 拖进来的图片文件，和松手的位置（网页坐标，左上角为原点）
    var onDropImages: (([URL], CGPoint) -> Void)?

    private func imageFiles(_ info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.image.identifier],
        ]
        return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        imageFiles(sender).isEmpty ? super.draggingEntered(sender) : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        imageFiles(sender).isEmpty ? super.draggingUpdated(sender) : .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        imageFiles(sender).isEmpty ? super.prepareForDragOperation(sender) : true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = imageFiles(sender)
        guard !files.isEmpty else { return super.performDragOperation(sender) }
        onDropImages?(files, Self.pagePoint(convert(sender.draggingLocation, from: nil), height: bounds.height, flipped: isFlipped, zoom: pageZoom))
        return true
    }

    /// 窗口坐标 → 网页里的坐标（网页从左上角算起，而且要除掉缩放比例）
    static func pagePoint(_ p: CGPoint, height: CGFloat, flipped: Bool, zoom: CGFloat) -> CGPoint {
        let y = flipped ? p.y : height - p.y
        let z = zoom > 0 ? zoom : 1
        return CGPoint(x: p.x / z, y: y / z)
    }
}
