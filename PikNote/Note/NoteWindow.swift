// 单个文件的窗口：.md 用自己的编辑器，PDF 用系统自带的 PDFKit，其他文件先给个“用默认软件打开”。
import SwiftUI
import PDFKit

struct NoteWindow: View {
    let url: URL
    @Environment(Library.self) private var library

    private var emoji: String { library.item(for: url)?.emoji ?? Library.defaultEmoji(for: url) }
    private var name: String { url.deletingPathExtension().lastPathComponent }

    var body: some View {
        Group {
            switch url.pathExtension.lowercased() {
            case "md": MarkdownNoteView(url: url, title: "\(emoji) \(name)")
            case "pdf": PDFNoteView(url: url).navigationTitle("\(emoji) \(name)")
            default: OtherFileView(url: url).navigationTitle("\(emoji) \(name)")
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .background(WindowReader { OpenNotes.register(url, window: $0) })
    }
}

/// 底部状态栏：左边文件位置，右边字数/页数
struct StatusBar: View {
    let url: URL
    let trailing: String

    var body: some View {
        HStack {
            Spacer()
            Text(trailing)
            Text(Self.friendlyPath(url))
                .lineLimit(1).truncationMode(.head)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 5)
        .background(.bar)
    }

    /// 把长长的系统路径变成“iCloud 云盘 / 笔记 / xxx.md”这种好读的样子
    static func friendlyPath(_ url: URL) -> String {
        var path = url.path(percentEncoded: false)
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let replacements = [
            (home + "Library/Mobile Documents/com~apple~CloudDocs/", L("iCloud 云盘/", "iCloud Drive/")),
            (home + "Library/CloudStorage/", ""),
            (home + "Desktop/", L("桌面/", "Desktop/")),
            (home + "Documents/", L("文稿/", "Documents/")),
            (home, "~/"),
        ]
        for (from, to) in replacements where path.hasPrefix(from) {
            path = to + path.dropFirst(from.count)
            break
        }
        return path.split(separator: "/").joined(separator: " / ")
    }
}

// MARK: - PDF

/// 控制 PDF 翻到哪一页（SwiftUI 和 PDFKit 之间传话）
@Observable
final class PDFController {
    var pageCount = 0
    /// 现在看到的是第几页（从 1 开始）
    var currentPage = 1
    @ObservationIgnored weak var view: PDFView?

    func go(to page: Int) {
        guard let document = view?.document, pageCount > 0 else { return }
        let target = min(max(page, 1), pageCount)
        if let p = document.page(at: target - 1) { view?.go(to: p) }
        currentPage = target
    }
}

struct PDFNoteView: View {
    let url: URL
    @State private var pdf = PDFController()

    var body: some View {
        VStack(spacing: 0) {
            PDFKitView(url: url, pdf: pdf)
            Divider()
            HStack(spacing: 6) {
                PageJumpField(pdf: pdf)
                Spacer()
                Text(StatusBar.friendlyPath(url))
                    .lineLimit(1).truncationMode(.head)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(.bar)
        }
    }
}

/// 页码直跳：“第 [ 3 ] / 12 页”，改数字回车就跳；滚动时数字跟着变
private struct PageJumpField: View {
    let pdf: PDFController
    @State private var text = "1"
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            if !Lang.shared.isEnglish { Text("第") }
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .multilineTextAlignment(.center)
                .frame(width: CGFloat(max(3, String(pdf.pageCount).count + 1)) * 9 + 12)
                .focused($focused)
                .onSubmit {
                    if let n = Int(text.trimmingCharacters(in: .whitespaces)) { pdf.go(to: n) }
                    text = String(pdf.currentPage) // 输错了就变回当前页
                    focused = false
                }
                .help(L("输入页码，回车跳转（⌘L）", "Type a page number and press Return (⌘L)"))
            Text(L("/ \(pdf.pageCount) 页", "/ \(pdf.pageCount)"))
                .monospacedDigit()
        }
        // 滚动翻页时更新数字（正在输入时不打扰）
        .onChange(of: pdf.currentPage) { _, page in if !focused { text = String(page) } }
        // ⌘L：跳到页码框，直接输数字
        .background {
            Button("") { focused = true }
                .keyboardShortcut("l", modifiers: .command)
                .opacity(0).allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

struct PDFKitView: NSViewRepresentable {
    let url: URL
    let pdf: PDFController

    func makeCoordinator() -> Coordinator { Coordinator(pdf: pdf) }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        pdf.view = view
        context.coordinator.observe(view)
        DispatchQueue.main.async { pdf.pageCount = view.document?.pageCount ?? 0 }
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {}

    final class Coordinator: NSObject {
        let pdf: PDFController
        private var observer: NSObjectProtocol?

        init(pdf: PDFController) { self.pdf = pdf }

        /// 翻页了（滚动、点链接、键盘）：更新当前页码
        func observe(_ view: PDFView) {
            observer = NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak self, weak view] _ in
                MainActor.assumeIsolated {
                    guard let view, let page = view.currentPage, let index = view.document?.index(for: page) else { return }
                    self?.pdf.currentPage = index + 1
                }
            }
        }
    }
}

// MARK: - 其他文件（第二版再做内置预览）

struct OtherFileView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().frame(width: 96, height: 96)
            Text(url.lastPathComponent).font(.title3.bold())
            Text(L("这种文件暂时不能在拾记里预览。", "PikNote can’t preview this kind of file yet.")).foregroundStyle(.secondary)
            Button(L("用默认软件打开", "Open with Default App")) { NSWorkspace.shared.open(url) }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
