// 格式工具栏：只在编辑区上方。只做 Markdown 存得下的格式（不做字体、字号、颜色、对齐、下划线）。
import SwiftUI

/// 光标处的格式（编辑器报过来的）
struct FormatState: Equatable {
    var section = -1
    var bold = false, italic = false, strike = false, highlight = false, code = false, link = false
    var block = "paragraph" // paragraph / h1 / h2 / h3 / code
    var list: String?       // bullet / ordered / task
    var quote = false
    var inTable = false
    /// 选中了一张图片（这时 ⌘+ / ⌘- 调图片大小）
    var imageSelected = false

    init() {}

    init(_ d: [String: Any]) {
        section = d["section"] as? Int ?? -1
        bold = d["bold"] as? Bool ?? false
        italic = d["italic"] as? Bool ?? false
        strike = d["strike"] as? Bool ?? false
        highlight = d["highlight"] as? Bool ?? false
        code = d["code"] as? Bool ?? false
        link = d["link"] as? Bool ?? false
        block = d["block"] as? String ?? "paragraph"
        list = d["list"] as? String
        quote = d["quote"] as? Bool ?? false
        inTable = d["inTable"] as? Bool ?? false
        imageSelected = d["imageSelected"] as? Bool ?? false
    }
}

struct FormatBar: View {
    let doc: MarkdownDocument
    @State private var showingLink = false
    @State private var linkText = ""
    @State private var showingTablePicker = false

    private var f: FormatState { doc.format }

    var body: some View {
        HStack(spacing: 2) {
            tool("bold", L("加粗（⌘B）", "Bold (⌘B)"), active: f.bold) { doc.command("bold") }
            tool("italic", L("斜体（⌘I）", "Italic (⌘I)"), active: f.italic) { doc.command("italic") }
            tool("strikethrough", L("删除线", "Strikethrough"), active: f.strike) { doc.command("strike") }
            tool("highlighter", L("高亮（⌘⇧H），存成 ==文字==", "Highlight (⌘⇧H), saved as ==text=="), active: f.highlight) { doc.command("highlight") }

            separator
            tool("list.bullet", L("无序列表", "Bulleted List"), active: f.list == "bullet") { doc.command("bulletList") }
            tool("list.number", L("有序列表", "Numbered List"), active: f.list == "ordered") { doc.command("orderedList") }
            tool("checklist", L("待办", "To-do"), active: f.list == "task") { doc.command("taskList") }
            tool("text.quote", L("引用", "Quote"), active: f.quote) { doc.command("quote") }

            separator
            tool("link", f.link ? L("去掉链接", "Remove Link") : L("链接", "Link"), active: f.link) {
                if f.link { doc.command("link") } else { linkText = ""; showingLink = true }
            }
            .popover(isPresented: $showingLink, arrowEdge: .bottom) { linkPopover }

            if f.inTable {
                Menu {
                    Button(L("在下方加一行", "Add Row Below")) { doc.command("addRow") }
                    Button(L("在右侧加一列", "Add Column Right")) { doc.command("addColumn") }
                    Divider()
                    Button(L("删除这一行", "Delete Row")) { doc.command("deleteRow") }
                    Button(L("删除这一列", "Delete Column")) { doc.command("deleteColumn") }
                    Divider()
                    Button(L("删除整个表格", "Delete Table")) { doc.command("deleteTable") }
                } label: {
                    Image(systemName: "tablecells").font(.system(size: 13))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(width: ToolButton.size.width, height: ToolButton.size.height)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.09)))
                .transition(.opacity)
                .help(L("表格：加减行列", "Table: add or remove rows and columns"))
            } else {
                tool("tablecells", L("插入表格", "Insert Table"), active: showingTablePicker) { showingTablePicker = true }
                    .popover(isPresented: $showingTablePicker, arrowEdge: .bottom) {
                        TableSizePicker { rows, cols in
                            showingTablePicker = false
                            doc.command("table", ["row": rows, "col": cols])
                        }
                    }
            }
            tool("photo", L("插入图片", "Insert Image")) { doc.insertImage() }
            tool("function", L("公式（⌘⇧M）：搜索插入，不用背 LaTeX", "Formula (⌘⇧M): search and insert, no LaTeX needed")) { doc.command("formulaBar") }
            tool("chevron.left.forwardslash.chevron.right", L("代码块", "Code Block"), active: f.block == "code") { doc.command("codeBlock") }
            tool("minus", L("分割线", "Divider")) { doc.command("hr") }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // 标题快捷键（工具栏上不放按钮，写标题直接打 # 更快）：⌥⌘1/2/3 标题，⌥⌘0 正文
        .background {
            Group {
                Button("") { doc.command("paragraph") }.keyboardShortcut("0", modifiers: [.command, .option])
                Button("") { doc.command("heading", 1) }.keyboardShortcut("1", modifiers: [.command, .option])
                Button("") { doc.command("heading", 2) }.keyboardShortcut("2", modifiers: [.command, .option])
                Button("") { doc.command("heading", 3) }.keyboardShortcut("3", modifiers: [.command, .option])
            }
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        // 在表格里 / 不在表格里：表格按钮换样子时淡入淡出
        .pikAnimation(Motion.quick, value: f.inTable)
        // 文件没打开成功（状态是空的）时不能用
        .disabled(doc.status.isEmpty)
    }

    private var separator: some View {
        Divider().frame(height: 16).padding(.horizontal, 6)
    }

    private func tool(_ symbol: String, _ help: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        ToolButton(symbol: symbol, help: help, active: active, action: action)
    }

    private var linkPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("链接地址", "Link Address")).font(.headline)
            TextField(L("https://… 或 讲义.pdf", "https://… or Notes.pdf"), text: $linkText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit(applyLink)
            Text(L("先选中文字再加链接；没选中就直接插入地址。\n指向同一层的笔记或 PDF 时写文件名即可，⌘+点击打开。", "Select text first to turn it into a link; otherwise the address itself is inserted.\nFor a note or PDF on the same shelf, just type its file name. ⌘-click a link to open it."))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(L("取消", "Cancel")) { showingLink = false }.keyboardShortcut(.cancelAction)
                Button(L("确定", "OK"), action: applyLink).keyboardShortcut(.defaultAction)
                    .disabled(linkText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }

    private func applyLink() {
        let href = linkText.trimmingCharacters(in: .whitespaces)
        guard !href.isEmpty else { return }
        showingLink = false
        // 文件名里有空格时，Markdown 链接需要转义
        let encoded = href.contains("://") ? href : (href.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? href)
        doc.command("link", encoded)
    }
}

/// 选表格大小：鼠标划过方格选几行几列，点一下插入（第一行是表头）
struct TableSizePicker: View {
    let onPick: (_ rows: Int, _ cols: Int) -> Void
    private let maxRows = 8, maxCols = 8
    private let cell: CGFloat = 20, gap: CGFloat = 3
    @State private var rows = 3
    @State private var cols = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("\(rows) 行 × \(cols) 列", "\(rows) rows × \(cols) columns"))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
            VStack(spacing: gap) {
                ForEach(1...maxRows, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(1...maxCols, id: \.self) { c in
                            let on = r <= rows && c <= cols
                            RoundedRectangle(cornerRadius: 3)
                                .fill(on ? Color.accentColor.opacity(r == 1 ? 0.55 : 0.3) : Color.primary.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(on ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: 1))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            // 用一整块区域算鼠标在第几格，比每格单独响应更顺滑
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active(let p) = phase {
                    cols = min(maxCols, max(1, Int(p.x / (cell + gap)) + 1))
                    rows = min(maxRows, max(2, Int(p.y / (cell + gap)) + 1)) // 至少表头 + 一行
                }
            }
            .onTapGesture { onPick(rows, cols) }
            Text(L("第一行是表头。插入后还能在表格菜单里加减行列。", "The first row is the header. You can add or remove rows and columns later from the table menu."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: CGFloat(maxCols) * (cell + gap), alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
    }
}

/// 工具栏上的一个按钮：鼠标移上去有淡淡的底色，按下轻轻一缩，选中的底色渐变出现
private struct ToolButton: View {
    /// 按钮大小（比图标大一圈，好点中）
    static let size = CGSize(width: 32, height: 28)

    let symbol: String
    let help: String
    let active: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: Self.size.width, height: Self.size.height)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.primary.opacity(active ? 0.10 : hovering ? 0.05 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .pikAnimation(Motion.quick, value: hovering)
        .pikAnimation(Motion.quick, value: active)
        .help(help)
    }
}
