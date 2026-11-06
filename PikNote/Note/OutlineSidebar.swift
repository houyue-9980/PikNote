// 左侧栏：只有大纲。按 # ## ### 自动生成，点击跳转；底部左边“关闭笔记本”，右边“库”。
// 有子标题的标题前面有小三角，点一下收起 / 展开；顶部可以全部折叠 / 全部展开。
import SwiftUI

struct OutlineHeading: Identifiable, Hashable {
    let index: Int
    let level: Int
    let text: String
    var id: Int { index }
}

struct OutlineSidebar: View {
    let doc: MarkdownDocument
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    /// 收起的标题（用“级别 + 文字 + 第几次出现”来认，前面加减标题时也不容易认错）
    @State private var collapsed: Set<String> = []
    /// 当前章节的高亮：换章节时从旧位置滑到新位置
    @Namespace private var highlight

    /// 最浅的那级标题顶格，其他按级别缩进
    private var minLevel: Int { doc.outline.map(\.level).min() ?? 1 }

    /// 每个标题的“身份”
    private var keys: [String] {
        var seen: [String: Int] = [:]
        return doc.outline.map { h in
            let base = "\(h.level)|\(h.text)"
            seen[base, default: 0] += 1
            return "\(base)|\(seen[base]!)"
        }
    }

    /// 标题下面有没有更深一级的标题
    private func hasChildren(_ i: Int) -> Bool {
        i + 1 < doc.outline.count && doc.outline[i + 1].level > doc.outline[i].level
    }

    /// 要显示的标题：被收起的标题下面更深的都藏起来
    private var visible: [(heading: OutlineHeading, key: String)] {
        var result: [(OutlineHeading, String)] = []
        var hideDeeperThan: Int?
        for (h, key) in zip(doc.outline, keys) {
            if let limit = hideDeeperThan {
                if h.level > limit { continue }
                hideDeeperThan = nil
            }
            result.append((h, key))
            if collapsed.contains(key) { hideDeeperThan = h.level }
        }
        return result
    }

    /// 光标所在的那一节；如果它被收起来了，就高亮它外面那个看得见的标题
    private var currentVisibleIndex: Int? {
        let section = doc.format.section
        guard section >= 0 else { return nil }
        return visible.last { $0.heading.index <= section }?.heading.index
    }

    private var anyFoldable: Bool { doc.outline.indices.contains(where: hasChildren) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("大纲", "Outline"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if anyFoldable {
                    Button(collapsed.isEmpty ? L("全部折叠", "Collapse All") : L("全部展开", "Expand All")) {
                        if collapsed.isEmpty {
                            collapsed = Set(doc.outline.indices.filter(hasChildren).map { keys[$0] })
                        } else {
                            collapsed = []
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if doc.outline.isEmpty {
                Text(L("用 # 开头写标题，\n这里就会出现大纲。", "Start a line with # to add a heading.\nIt will show up here."))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(visible, id: \.heading.index) { item in
                            let h = item.heading
                            OutlineRow(
                                heading: h,
                                indent: CGFloat(h.level - minLevel) * 12,
                                current: h.index == currentVisibleIndex,
                                highlight: highlight,
                                foldable: hasChildren(h.index),
                                folded: collapsed.contains(item.key),
                                toggle: {
                                    if collapsed.contains(item.key) { collapsed.remove(item.key) } else { collapsed.insert(item.key) }
                                }
                            ) {
                                doc.scrollToHeading?(h.index)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .pikAnimation(Motion.quick, value: collapsed)
                    .pikAnimation(Motion.standard, value: currentVisibleIndex)
                }
            }

            Divider()
            // 底部两个按钮：左边关掉这本笔记（回到库），右边只是把库窗口叫到前面（笔记还开着）
            HStack(spacing: 0) {
                FooterButton(title: L("关闭", "Close"), systemImage: "xmark.circle",
                             help: L("关闭这篇笔记，回到库（⌘W）", "Close this note and go back to the Library (⌘W)")) {
                    openWindow(id: "shelf")
                    dismiss()
                }
                Divider().frame(height: 22)
                FooterButton(title: L("库", "Library"), systemImage: "books.vertical",
                             help: L("打开库，笔记保持打开（⌘⇧L）", "Show the Library and keep this note open (⌘⇧L)")) {
                    openWindow(id: "shelf")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

private struct OutlineRow: View {
    let heading: OutlineHeading
    let indent: CGFloat
    let current: Bool
    let highlight: Namespace.ID
    let foldable: Bool
    let folded: Bool
    let toggle: () -> Void
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 2) {
            // 小三角：有子标题才显示，没有的留出同样的位置，文字才对得齐
            Button(action: toggle) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(folded ? 0 : 90))
                    .frame(width: 16, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(foldable ? 1 : 0)
            .disabled(!foldable)
            .help(folded ? L("展开", "Expand") : L("折叠", "Collapse"))

            Button(action: action) {
                Text(heading.text.isEmpty ? L("（空标题）", "(Empty heading)") : heading.text)
                    .font(.system(size: 13, weight: heading.level == 1 ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(heading.text)
        }
        .padding(.leading, indent)
        .padding(.trailing, 8)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering && !current ? Color.primary.opacity(0.05) : .clear)
                if current {
                    // 同一块高亮在各行之间移动，所以换章节时是“滑过去”
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.09))
                        .matchedGeometryEffect(id: "current", in: highlight)
                }
            }
        }
        .onHover { hovering = $0 }
        .pikAnimation(Motion.quick, value: hovering)
    }
}

/// 侧栏底部的按钮：整块都能点（不只是文字），鼠标放上去有底色
private struct FooterButton: View {
    let title: String
    let systemImage: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            // 侧栏拉窄了放不下图标时，只显示文字
            ViewThatFits(in: .horizontal) {
                Label(title, systemImage: systemImage)
                Text(title)
            }
                .font(.callout)
                .lineLimit(1)
                // minWidth: 0 → 两个按钮不管文字长短都平分宽度，分隔线正好在中间
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.96, cornerRadius: 6))
        .foregroundStyle(hovering ? .primary : .secondary)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.07) : .clear))
        .onHover { hovering = $0 }
        .pikAnimation(Motion.quick, value: hovering)
        .help(help)
    }
}
