// 记住每个文件对应哪个窗口，保证“每篇一个窗口”：已经开着的就直接拿到最前面。
import SwiftUI

enum OpenNotes {
    private final class WeakWindow { weak var window: NSWindow?; init(_ w: NSWindow) { window = w } }
    private static var windows: [String: WeakWindow] = [:]

    private static func key(_ url: URL) -> String { url.standardizedFileURL.path }

    /// 打开一个文件：已有窗口就切过去，没有就新开
    static func open(_ url: URL, using openWindow: OpenWindowAction) {
        if let window = windows[key(url)]?.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(value: url)
        }
    }

    static func register(_ url: URL, window: NSWindow) {
        windows[key(url)] = WeakWindow(window)
    }

    private final class WeakDocument { weak var doc: MarkdownDocument?; init(_ d: MarkdownDocument) { doc = d } }
    private static var documents: [String: WeakDocument] = [:]

    static func register(_ url: URL, document: MarkdownDocument) {
        documents[key(url)] = WeakDocument(document)
    }

    /// 某个窗口里打开的笔记（菜单命令要知道“当前这篇”是谁）
    static func document(in window: NSWindow?) -> MarkdownDocument? {
        guard let window else { return nil }
        guard let key = windows.first(where: { $0.value.window === window })?.key else { return nil }
        return documents[key]?.doc
    }

    /// 文件要被移动 / 改名了：如果正开着，先把没存的存好，再关掉窗口，之后不再往旧位置写
    static func prepareToMove(_ url: URL) {
        if let doc = documents[key(url)]?.doc {
            doc.saveNow()
            doc.detach()
        }
        documents[key(url)] = nil
        if let window = windows[key(url)]?.window {
            window.close()
        }
        windows[key(url)] = nil
    }
}

/// 帮 SwiftUI 视图拿到它所在的 NSWindow
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { if let window = view.window { onWindow(window) } }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
