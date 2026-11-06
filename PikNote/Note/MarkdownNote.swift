// .md 笔记窗口：Swift 负责读写文件，网页里的 Milkdown 负责编辑。
// 两边只传两件事：打开时把文字交给编辑器；编辑后拿回 Markdown 写回文件。
import SwiftUI
import WebKit
import os

let editorLog = Logger(subsystem: "io.github.houyue9980.piknote", category: "editor")

struct MarkdownNoteView: View {
    let url: URL
    let title: String
    @State private var doc: MarkdownDocument
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var scheme

    init(url: URL, title: String) {
        self.url = url
        self.title = title
        _doc = State(initialValue: MarkdownDocument(url: url))
    }

    var body: some View {
        NavigationSplitView {
            OutlineSidebar(doc: doc)
                .navigationSplitViewColumnWidth(min: 150, ideal: 190, max: 320)
        } detail: {
            VStack(spacing: 0) {
                if let error = doc.errorMessage {
                    Text(error)
                        .font(.callout).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(8)
                        .background(.red.opacity(0.85))
                }
                FormatBar(doc: doc)
                Divider()
                MarkdownEditorView(doc: doc, theme: AppearanceSettings.shared.effective(scheme).rawValue)
                Divider()
                StatusBar(url: url, trailing: L("\(doc.wordCount) 字", "\(doc.wordCount) words")
                          + (EditorZoom.shared.label.map { " · " + $0 } ?? ""))
            }
            .pikPageBackground()
        }
        .navigationTitle(title)
        .navigationSubtitle(doc.status)
        .onAppear {
            // ⌘+点击链接打开其他笔记或 PDF 时，也遵守“每篇一个窗口”
            doc.openFile = { [openWindow] url in OpenNotes.open(url, using: openWindow) }
            OpenNotes.register(url, document: doc)
        }
        .onDisappear { doc.saveNow() } // 关窗口时，没来得及保存的立刻保存
    }
}

/// 一篇 .md 笔记：负责读文件、存文件、感知外部修改
@Observable
final class MarkdownDocument {
    let url: URL
    var status = ""
    var wordCount = 0
    var errorMessage: String?
    /// 大纲：文章里的标题
    var outline: [OutlineHeading] = []
    /// 光标处的格式，工具栏按钮按下的样子
    var format = FormatState()

    /// 编辑器那边注册：有新文字（打开 / 外部修改）要显示时调用
    @ObservationIgnored var pushToEditor: ((String) -> Void)?
    /// 编辑器那边注册：执行一个工具栏命令，比如 ("bold", nil)、("heading", 2)
    @ObservationIgnored var runCommand: ((String, Any?) -> Void)?
    /// 编辑器那边注册：跳到第几个标题
    @ObservationIgnored var scrollToHeading: ((Int) -> Void)?
    /// 窗口那边注册：在拾记里打开另一个文件
    @ObservationIgnored var openFile: ((URL) -> Void)?
    /// 磁盘上的内容，用来判断“内容真有变化才写回”
    @ObservationIgnored private var savedText = ""
    /// 编辑器里还没存的内容
    @ObservationIgnored private var pendingText: String?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(url: URL) {
        self.url = url
        load()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .piknoteFilesChanged, object: nil, queue: .main) { [weak self] note in
            let paths = note.userInfo?["paths"] as? [String] ?? []
            MainActor.assumeIsolated { self?.filesChanged(paths) }
        })
        // 退出软件前，没来得及保存的立刻保存
        observers.append(center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        })
    }

    /// 工具栏按钮调用
    func command(_ name: String, _ argument: Any? = nil) {
        runCommand?(name, argument)
    }

    /// ⌘+点击了链接：网址用浏览器开；指向其他笔记 / PDF 就在拾记里开新窗口
    func openLink(_ href: String) {
        if let link = URL(string: href), let scheme = link.scheme, scheme != "file" {
            NSWorkspace.shared.open(link)
            return
        }
        let path = href.removingPercentEncoding ?? href
        let target = URL(fileURLWithPath: path, relativeTo: url.deletingLastPathComponent()).standardizedFileURL
        guard FileManager.default.fileExists(atPath: target.path) else {
            errorMessage = L("找不到链接指向的文件：\(path)", "Can’t find the linked file: \(path)")
            return
        }
        if ["md", "pdf"].contains(target.pathExtension.lowercased()) {
            openFile?(target)
        } else {
            NSWorkspace.shared.open(target)
        }
    }

    /// 选一张图片插入：放进笔记所在的文件夹，用相对路径引用
    func insertImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.message = L("选择要插入的图片（会复制一份到这层书架的 assets 文件夹里）",
                          "Choose an image to insert (a copy goes into this shelf’s assets folder)")
        guard panel.runModal() == .OK, let picked = panel.url else { return }
        do {
            let src = try Self.placeImage(picked, forNote: url)
            command("image", ["src": src, "alt": picked.deletingPathExtension().lastPathComponent])
        } catch {
            errorMessage = L("图片复制失败：\(error.localizedDescription)", "Couldn’t copy the image: \(error.localizedDescription)")
        }
    }

    /// 拖进来 / 粘贴的图片：数据存进 assets，返回笔记里要写的相对路径
    static func saveImageData(_ data: Data, name: String, forNote note: URL) throws -> String {
        let assets = note.deletingLastPathComponent().appendingPathComponent(assetsFolder)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        // 文件名里不能有 / 和 :
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ".")
        let target = Library.uniqueDestination(for: safe.isEmpty ? "image.png" : safe, in: assets)
        try data.write(to: target, options: .atomic)
        return assetsFolder + "/" + target.lastPathComponent
    }

    /// 附件文件夹的名字（Typora 等软件默认也用这个）。书架不显示子文件夹，所以图片不会出现在书架上
    static let assetsFolder = "assets"

    /// 把图片放进笔记所在那层书架的 assets 文件夹，返回笔记里要写的相对路径（比如 "assets/回归图.png"）。
    /// 图片本来就在这层书架（或它的 assets）里：不复制，直接引用。
    static func placeImage(_ image: URL, forNote note: URL) throws -> String {
        let shelf = note.deletingLastPathComponent().standardizedFileURL
        let assets = shelf.appendingPathComponent(assetsFolder)
        let imageFolder = image.deletingLastPathComponent().standardizedFileURL
        if imageFolder.path == shelf.path { return image.lastPathComponent }
        if imageFolder.path == assets.standardizedFileURL.path { return assetsFolder + "/" + image.lastPathComponent }
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        let target = Library.uniqueDestination(for: image.lastPathComponent, in: assets)
        try FileManager.default.copyItem(at: image, to: target)
        return assetsFolder + "/" + target.lastPathComponent
    }

    /// 编辑器第一次准备好时要显示的文字
    var initialText: String { savedText }

    private func load() {
        do {
            savedText = try String(contentsOf: url, encoding: .utf8)
            wordCount = Self.count(savedText)
            status = L("已保存", "Saved")
            errorMessage = nil
        } catch {
            errorMessage = L("打不开这个文件：\(error.localizedDescription)", "Couldn’t open this file: \(error.localizedDescription)")
        }
    }

    /// 编辑器说内容变了：停止输入约 1 秒后保存
    func editorChanged(_ markdown: String) {
        guard !detached else { return }
        pendingText = markdown
        wordCount = Self.count(markdown)
        status = L("编辑中…", "Editing…")
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self.saveNow()
        }
    }

    /// 文件被移走了：以后不再读写这个位置
    @ObservationIgnored private var detached = false
    func detach() {
        saveTask?.cancel()
        pendingText = nil
        detached = true
    }

    func saveNow() {
        saveTask?.cancel()
        guard !detached, let text = pendingText else { return }
        pendingText = nil
        guard text != savedText else { status = L("已保存", "Saved"); return }
        do {
            // 先写临时文件再替换，断电也不会写出半个文件
            try text.write(to: url, atomically: true, encoding: .utf8)
            savedText = text
            status = L("已保存", "Saved")
            errorMessage = nil
        } catch {
            pendingText = text
            errorMessage = L("保存失败：\(error.localizedDescription)", "Couldn’t save: \(error.localizedDescription)")
        }
    }

    /// 根文件夹里有文件变了：如果是这篇，而且不是我们自己刚存的，就刷新编辑器
    private func filesChanged(_ paths: [String]) {
        let mine = url.standardizedFileURL.path
        guard paths.contains(where: { URL(fileURLWithPath: $0).standardizedFileURL.path == mine }) else { return }
        guard !detached, pendingText == nil, // 正在编辑时不打断，以本机为准
              let disk = try? String(contentsOf: url, encoding: .utf8),
              disk != savedText
        else { return }
        savedText = disk
        wordCount = Self.count(disk)
        status = L("已从磁盘更新", "Updated from disk")
        pushToEditor?(disk)
    }

    /// 字数：中文按字算，英文按词算
    nonisolated static func count(_ text: String) -> Int {
        var n = 0, inWord = false
        for ch in text {
            if ch.unicodeScalars.first.map({ (0x4E00...0x9FFF).contains($0.value) }) == true {
                n += 1; inWord = false
            } else if ch.isLetter || ch.isNumber {
                if !inWord { n += 1; inWord = true }
            } else {
                inWord = false
            }
        }
        return n
    }
}

/// 把网页编辑器嵌进 SwiftUI
struct MarkdownEditorView: NSViewRepresentable {
    let doc: MarkdownDocument
    /// light / dark / sepia
    let theme: String

    func makeCoordinator() -> Coordinator { Coordinator(doc: doc) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "piknote")
        let web = EditorWebView(frame: .zero, configuration: config)
        // 从访达拖进来的图片：复制进 assets，插在松手的位置
        web.onDropImages = { [weak web, doc] files, point in
            var items: [[String: String]] = []
            for file in files {
                do {
                    let src = try MarkdownDocument.placeImage(file, forNote: doc.url)
                    items.append(["src": src, "alt": file.deletingPathExtension().lastPathComponent])
                } catch {
                    doc.errorMessage = L("图片复制失败：\(error.localizedDescription)", "Couldn’t copy the image: \(error.localizedDescription)")
                }
            }
            guard !items.isEmpty else { return }
            web?.window?.makeFirstResponder(web)
            web?.callAsyncJavaScript("window.piknote.insertImagesAt(x, y, items)",
                                     arguments: ["x": point.x, "y": point.y, "items": items], in: nil, in: .page)
        }
        web.navigationDelegate = context.coordinator
        #if DEBUG
        web.isInspectable = true // 开发版：右键“检查元素”可以调试网页（正式版不开）
        #endif
        web.setValue(false, forKey: "drawsBackground")
        context.coordinator.web = web
        web.pageZoom = EditorZoom.shared.scale // 用上次的缩放比例
        doc.pushToEditor = { [weak coordinator = context.coordinator] text in coordinator?.load(text) }
        doc.runCommand = { [weak web] name, argument in
            web?.callAsyncJavaScript("window.piknote.command(name, arg)", arguments: ["name": name, "arg": argument ?? NSNull()], in: nil, in: .page)
        }
        doc.scrollToHeading = { [weak web] index in
            web?.callAsyncJavaScript("window.piknote.scrollToHeading(i)", arguments: ["i": index], in: nil, in: .page)
        }
        let index = Coordinator.editorPage
        // 允许读取整个磁盘上的文件，笔记里的图片（相对路径）才能显示
        web.loadFileURL(index, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.setTheme(theme)
        let scale = EditorZoom.shared.scale
        if abs(web.pageZoom - scale) > 0.001 { web.pageZoom = scale }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let editorPage = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "editor")!
        let doc: MarkdownDocument
        weak var web: WKWebView?

        @ObservationIgnored private var languageObserver: NSObjectProtocol?
        @ObservationIgnored private var colorsObserver: NSObjectProtocol?

        /// 标题颜色：用现在这个主题的那一套
        func setHeadingColors() {
            guard pageReady else { return }
            let theme = appliedTheme.flatMap(Theme.init(rawValue:)) ?? .light
            web?.callAsyncJavaScript("window.piknote.setHeadingColors(c)", arguments: ["c": Personalization.shared.forEditor(theme: theme)], in: nil, in: .page)
            web?.callAsyncJavaScript("window.piknote.setTypography(t)", arguments: ["t": Personalization.shared.typographyForEditor], in: nil, in: .page)
        }

        init(doc: MarkdownDocument) {
            self.doc = doc
            super.init()
            // 设置里换了语言：编辑器（公式快捷栏等）也跟着换
            languageObserver = NotificationCenter.default.addObserver(forName: .piknoteLanguageChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setEditorLanguage() }
            }
            // 设置里改了标题颜色：编辑器马上换
            colorsObserver = NotificationCenter.default.addObserver(forName: .piknoteHeadingColorsChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setHeadingColors() }
            }
        }

        /// 换主题：只在变了的时候告诉编辑器
        private var currentTheme: String?
        private var pageReady = false
        func setTheme(_ theme: String) {
            guard pageReady else { currentTheme = theme; return }
            guard theme != appliedTheme else { return }
            appliedTheme = theme
            setHeadingColors() // 换了主题，标题颜色也换成那一套
            web?.callAsyncJavaScript("window.piknote.setTheme(t)", arguments: ["t": theme], in: nil, in: .page)
        }
        private var appliedTheme: String?

        func setEditorLanguage() {
            web?.callAsyncJavaScript("window.piknote.setLang(lang)", arguments: ["lang": Lang.shared.current.rawValue], in: nil, in: .page)
        }

        func load(_ text: String) {
            // 用参数传文字，不用拼字符串，任何特殊字符都不会出错
            web?.callAsyncJavaScript("await window.piknote.load(md)", arguments: ["md": text], in: nil, in: .page)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            if ["ready", "loaded", "openLink"].contains(type) { editorLog.notice("editor says: \(type, privacy: .public) [\(self.doc.url.lastPathComponent, privacy: .public)]") }
            switch type {
            case "ready":
                setEditorLanguage()
                pageReady = true
                if let theme = currentTheme { currentTheme = nil; setTheme(theme) }
                setHeadingColors()
                // 图片等相对路径以笔记所在的文件夹为准
                let folder = doc.url.deletingLastPathComponent().absoluteString
                web?.callAsyncJavaScript("window.piknote.setBase(href)", arguments: ["href": folder], in: nil, in: .page)
                load(doc.initialText)
            case "loaded":
                // 让编辑器拿到键盘焦点
                web?.window?.makeFirstResponder(web)
                web?.evaluateJavaScript("window.piknote.focusEditor()")
            case "outline":
                if let list = body["headings"] as? [[String: Any]] {
                    doc.outline = list.enumerated().map { i, h in
                        OutlineHeading(index: i, level: h["level"] as? Int ?? 1, text: h["text"] as? String ?? "")
                    }
                }
            case "state":
                if let state = body["state"] as? [String: Any] { doc.format = FormatState(state) }
            case "openLink":
                if let href = body["href"] as? String { doc.openLink(href) }
            case "saveImage":
                // 拖进来 / 粘贴的图片：存进 assets，再告诉编辑器插到哪
                guard let id = body["id"] as? Int, let name = body["name"] as? String,
                      let base64 = body["data"] as? String, let data = Data(base64Encoded: base64) else { return }
                var src = ""
                do {
                    src = try MarkdownDocument.saveImageData(data, name: name, forNote: doc.url)
                } catch {
                    doc.errorMessage = L("图片保存失败：\(error.localizedDescription)", "Couldn’t save the image: \(error.localizedDescription)")
                }
                let alt = (name as NSString).deletingPathExtension
                web?.callAsyncJavaScript("window.piknote.imageSaved(id, src, alt)", arguments: ["id": id, "src": src, "alt": alt], in: nil, in: .page)
            case "changed":
                if let md = body["markdown"] as? String { doc.editorChanged(md) }
            default:
                break
            }
        }

        /// 不让网页跳走（比如点了链接、拖进来一个文件），编辑器页面要一直留着
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            // 只放行编辑器页面本身，其他一律拦下
            let allow = action.request.url?.standardizedFileURL == Self.editorPage.standardizedFileURL
            editorLog.notice("navigation \(allow ? "allowed" : "blocked", privacy: .public): \(action.request.url?.lastPathComponent ?? "-", privacy: .public) current=\(webView.url?.lastPathComponent ?? "nil", privacy: .public)")
            return allow ? .allow : .cancel
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            editorLog.error("load failed: \(error.localizedDescription, privacy: .public)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            editorLog.error("load failed (provisional): \(error.localizedDescription, privacy: .public)")
        }
    }
}
