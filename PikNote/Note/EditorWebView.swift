// 编辑器用的网页视图：自己接住从访达拖进来的图片。
// （嵌在软件里的网页不会把拖进来的文件交给编辑器，所以由 Mac 这边直接处理）
import AppKit
import WebKit
import UniformTypeIdentifiers

final class EditorWebView: WKWebView {
    /// 拖进来的图片文件，和松手的位置（网页坐标，左上角为原点）
    var onDropImages: (([URL], CGPoint) -> Void)?

    /// 图片的扩展名。按扩展名认，不按文件内容认：OneDrive 等网盘里“仅在线”的文件还没下载，
    /// 系统读不出它是什么类型，按内容认就会漏掉，图片变成网页自己处理（只剩一个名字）
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tif", "tiff", "bmp", "svg", "avif"]

    private func imageFiles(_ info: NSDraggingInfo) -> [URL] {
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
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

    // MARK: - 右键链接

    /// 右键菜单里点了“打开链接”：交给笔记去开（网址用浏览器，笔记 / PDF 在拾记里开）
    var onOpenLink: ((String) -> Void)?

    /// 网页自带的链接菜单项（打开链接、在新窗口打开、下载、拷贝链接）。
    /// 编辑器页面不允许跳走，这些点了也没用，换成拾记自己的
    private static let webKitLinkItems: Set<String> = [
        "WKMenuItemIdentifierOpenLink", "WKMenuItemIdentifierOpenLinkInNewWindow",
        "WKMenuItemIdentifierDownloadLinkedFile", "WKMenuItemIdentifierCopyLink",
    ]

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        let linkItems = menu.items.filter { Self.webKitLinkItems.contains($0.identifier?.rawValue ?? "") }
        guard !linkItems.isEmpty else { return } // 不是右键点在链接上
        linkItems.forEach(menu.removeItem)
        while menu.items.first?.isSeparatorItem == true { menu.removeItem(at: 0) }
        let ours = [
            linkMenuItem(L("打开链接", "Open Link"), #selector(openContextLink)),
            linkMenuItem(L("重命名链接…", "Rename Link…"), #selector(renameContextLink)),
            linkMenuItem(L("拷贝链接地址", "Copy Link Address"), #selector(copyContextLink)),
            linkMenuItem(L("去掉链接", "Remove Link"), #selector(removeContextLink)),
        ]
        if !menu.items.isEmpty { menu.insertItem(.separator(), at: 0) }
        for item in ours.reversed() { menu.insertItem(item, at: 0) }
    }

    private func linkMenuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    /// 问网页：右键点的是哪个链接（href 和显示的文字）
    private func withContextLink(_ body: @escaping (_ href: String, _ text: String) -> Void) {
        callAsyncJavaScript("return window.piknote.contextLink()", arguments: [:], in: nil, in: .page) { result in
            guard case .success(let value) = result, let link = value as? [String: Any],
                  let href = link["href"] as? String else { return }
            body(href, link["text"] as? String ?? "")
        }
    }

    @objc private func openContextLink() {
        withContextLink { [weak self] href, _ in self?.onOpenLink?(href) }
    }

    @objc private func copyContextLink() {
        withContextLink { href, _ in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(href.contains("://") ? href : (href.removingPercentEncoding ?? href), forType: .string)
        }
    }

    @objc private func removeContextLink() {
        callAsyncJavaScript("window.piknote.removeContextLink()", arguments: [:], in: nil, in: .page)
    }

    /// 弹出小窗口：改链接显示的文字，顺便也能改地址
    @objc private func renameContextLink() {
        withContextLink { [weak self] href, text in
            guard let self, let window = self.window else { return }
            // 指向文件的地址存的是转义过的（空格 → %20），给人看时还原
            let isWeb = href.contains("://")
            let nameField = NSTextField(string: text)
            let addressField = NSTextField(string: isWeb ? href : (href.removingPercentEncoding ?? href))
            for field in [nameField, addressField] {
                field.translatesAutoresizingMaskIntoConstraints = false
                field.widthAnchor.constraint(equalToConstant: 280).isActive = true
            }
            let grid = NSGridView(views: [
                [NSTextField(labelWithString: L("显示文字", "Text")), nameField],
                [NSTextField(labelWithString: L("链接地址", "Address")), addressField],
            ])
            grid.rowSpacing = 8
            grid.column(at: 0).xPlacement = .trailing
            grid.frame.size = grid.fittingSize

            let alert = NSAlert()
            alert.messageText = L("重命名链接", "Rename Link")
            alert.addButton(withTitle: L("确定", "OK"))
            alert.addButton(withTitle: L("取消", "Cancel"))
            alert.accessoryView = grid
            alert.window.initialFirstResponder = nameField
            alert.beginSheetModal(for: window) { [weak self] response in
                guard let self else { return }
                window.makeFirstResponder(self)
                guard response == .alertFirstButtonReturn else { return }
                let newText = nameField.stringValue.trimmingCharacters(in: .whitespaces)
                var newHref = addressField.stringValue.trimmingCharacters(in: .whitespaces)
                if newHref.isEmpty { newHref = href }
                else if !newHref.contains("://") {
                    // 和工具栏加链接一样：文件名里有空格时要转义
                    newHref = newHref.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? newHref
                }
                self.callAsyncJavaScript("window.piknote.renameContextLink(text, href)",
                                         arguments: ["text": newText, "href": newHref], in: nil, in: .page)
            }
        }
    }

    /// 窗口坐标 → 网页里的坐标（网页从左上角算起，而且要除掉缩放比例）
    static func pagePoint(_ p: CGPoint, height: CGFloat, flipped: Bool, zoom: CGFloat) -> CGPoint {
        let y = flipped ? p.y : height - p.y
        let z = zoom > 0 ? zoom : 1
        return CGPoint(x: p.x / z, y: y / z)
    }
}
