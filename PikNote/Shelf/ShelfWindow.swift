// 书架主界面：每层书架一个大标题，下面是方形表情图标网格。
import SwiftUI

// MARK: - 主页上拖动图标（app 自己处理，不用系统拖放）
// 系统拖放松手时，跟着鼠标的小图标要在原地淡出一会儿，看起来像多出一个。
// 自己处理就没有这个问题：松手时影子直接消失，图标同时出现在新位置。

/// 松手会放到哪里
enum ShelfDropTarget: Equatable {
    case before(item: URL, folder: URL) // 放在某个图标前面
    case end(shelf: URL)                // 放到某层最后
}

@Observable
final class ShelfDrag {
    /// 正在拖的图标；nil = 没在拖
    var item: ShelfItem?
    /// 鼠标在书架内容里的位置（坐标系 "shelf"）
    var location: CGPoint = .zero
    /// 按下时鼠标离图标中心多远：影子跟着鼠标走时保持这个距离
    var grab: CGSize = .zero
    var target: ShelfDropTarget?
    /// 各个图标、各层书架在书架内容里的位置
    var tileFrames: [URL: CGRect] = [:]
    var shelfFrames: [URL: CGRect] = [:]

    /// 鼠标在 point 时，松手会放到哪里
    func target(at point: CGPoint) -> ShelfDropTarget? {
        guard let dragged = item?.url else { return nil }
        if let (url, _) = tileFrames.first(where: { $0.key != dragged && $0.value.contains(point) }) {
            return .before(item: url, folder: url.deletingLastPathComponent())
        }
        if let (url, _) = shelfFrames.first(where: { $0.value.insetBy(dx: -12, dy: -12).contains(point) }) {
            return .end(shelf: url)
        }
        return nil
    }
}

struct TileFrameKey: PreferenceKey {
    static let defaultValue: [URL: CGRect] = [:]
    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) { value.merge(nextValue()) { $1 } }
}
struct ShelfFrameKey: PreferenceKey {
    static let defaultValue: [URL: CGRect] = [:]
    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) { value.merge(nextValue()) { $1 } }
}

struct ShelfWindow: View {
    @Environment(Library.self) private var library
    @Environment(\.openWindow) private var openWindow
    /// 拖到窗口空白处的文件：等用户选放哪层
    @State private var pendingImport: [URL] = []
    @State private var importMessage: String?
    @State private var drag = ShelfDrag()

    var body: some View {
        @Bindable var library = library
        Group {
            if library.rootURL == nil {
                WelcomeView()
            } else if library.shelves.isEmpty {
                EmptyShelfView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(library.shelves) { shelf in
                            ShelfRow(shelf: shelf) { urls in importFiles(urls, into: shelf.url) }
                        }
                    }
                    .pikAnimation(Motion.standard, value: library.shelves.map(\.id))
                    .padding(.horizontal, 48)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // 拖动中的影子：跟着鼠标走
                    .overlay(alignment: .topLeading) {
                        if let item = drag.item {
                            DragGhost(item: item)
                                .position(x: drag.location.x - drag.grab.width, y: drag.location.y - drag.grab.height)
                                .allowsHitTesting(false)
                        }
                    }
                    .coordinateSpace(name: "shelf")
                    .onPreferenceChange(TileFrameKey.self) { drag.tileFrames = $0 }
                    .onPreferenceChange(ShelfFrameKey.self) { drag.shelfFrames = $0 }
                }
                .environment(drag)
                // 拖到空白处（不在任何一层上）：只有一层就直接放进去，否则问放哪层
                .dropDestination(for: URL.self) { urls, _ in
                    guard !urls.isEmpty else { return false }
                    if library.shelves.count == 1 {
                        importFiles(urls, into: library.shelves[0].url)
                    } else {
                        pendingImport = urls
                    }
                    return true
                }
            }
        }
        .confirmationDialog(
            pendingImport.count == 1 ? L("把“\(pendingImport[0].lastPathComponent)”放到哪一层？", "Put “\(pendingImport[0].lastPathComponent)” on which shelf?") : L("把这 \(pendingImport.count) 个文件放到哪一层？", "Put these \(pendingImport.count) files on which shelf?"),
            isPresented: Binding(get: { !pendingImport.isEmpty }, set: { if !$0 { pendingImport = [] } })
        ) {
            ForEach(library.shelves) { shelf in
                Button(shelf.name) {
                    let urls = pendingImport
                    pendingImport = []
                    importFiles(urls, into: shelf.url)
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) { pendingImport = [] }
        } message: {
            Text(L("从外面拖进来的文件会复制一份，原文件不动。", "Files dragged in from elsewhere are copied. The originals stay where they are."))
        }
        .alert(L("导入提示", "Import Notice"), isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button(L("好", "OK")) { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
        .frame(minWidth: 520, minHeight: 360)
        .pikPageBackground()
        .pikToolbarBackground()
        .navigationTitle(L("拾记", "PikNote"))
        .onAppear {
            // 调试用：启动参数 -PikNoteOpen <文件路径> 会直接打开这个文件
            if let path = UserDefaults.standard.string(forKey: "PikNoteOpen") {
                let url = URL(fileURLWithPath: path)
                OpenNotes.open(url, using: openWindow)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { library.showingManager = true } label: { Image(systemName: "square.grid.2x2") }
                    .help(L("书架管理", "Manage Shelves"))
                    .disabled(library.rootURL == nil)
                Button { library.showingNewNote = true } label: { Image(systemName: "square.and.pencil") }
                    .help(L("新建笔记（⌘N）", "New Note (⌘N)"))
                    .disabled(library.rootURL == nil)
            }
        }
        .sheet(isPresented: $library.showingNewNote) {
            NewNoteSheet().environment(library)
        }
        .sheet(isPresented: $library.showingManager) {
            ShelfManager().environment(library)
        }
    }

    private func importFiles(_ urls: [URL], into shelf: URL) {
        // 拖进来 / 从别的书架拖过来：同样不播放让位动画
        importMessage = withoutAnimation { library.importFiles(urls, into: shelf) }
    }
}

/// 一层书架
struct ShelfRow: View {
    let shelf: Shelf
    /// 从访达拖文件到这一层上
    let onImport: ([URL]) -> Void
    @Environment(Library.self) private var library
    @Environment(ShelfDrag.self) private var drag
    @State private var targeted = false
    @State private var hoveringHeader = false
    /// 收起来的书架（按名字记，换一行一个）；记在这台电脑上，重开软件还是收着的
    @AppStorage("collapsedShelves") private var collapsedRaw = ""
    /// 展开时内容有多高（量出来的）：收起 / 展开时在 0 和这个高度之间平滑变化
    @State private var contentHeight: CGFloat = 0

    /// 高亮这一层：从访达拖文件进来，或者在 app 里拖图标、松手会放到这层最后
    private var highlighted: Bool { targeted || drag.target == .end(shelf: shelf.url) }

    private var collapsedNames: Set<String> { Set(collapsedRaw.split(separator: "\n").map(String.init)) }
    /// 界面上用的收起状态（自己的状态，动画挂在它上面）；和上面存的设置保持一致
    @State private var collapsed = false
    @State private var didLoad = false

    /// 点标题：收起 / 展开这一层；按住 ⌥ 点：所有书架一起收起 / 展开
    private func toggle() {
        var names = collapsedNames
        let collapse = !collapsed
        let targets = NSEvent.modifierFlags.contains(.option) ? library.shelves.map(\.name) : [shelf.name]
        for name in targets {
            if collapse { names.insert(name) } else { names.remove(name) }
        }
        // 整个窗口一起做动画：不光这一层收起来，下面的书架也平滑地跟上来
        withPikAnimation(Motion.drawer) { collapsed = collapse }
        collapsedRaw = names.sorted().joined(separator: "\n") // 存起来；其他书架从这里得知“全部收起”
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button(action: toggle) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(collapsed ? 0 : 90))
                            .opacity(hoveringHeader || collapsed ? 1 : 0.45)
                        Text(shelf.name)
                            .font(.system(size: 17, weight: .semibold))
                        if collapsed {
                            // 收起时：显示有几篇，再露出前几个图标的表情，知道里面大概是什么
                            Text("\(shelf.items.count)")
                                .font(.callout).foregroundStyle(.secondary)
                            HStack(spacing: 2) {
                                ForEach(shelf.items.prefix(6)) { Text($0.emoji).font(.system(size: 14)) }
                            }
                            .transition(.opacity)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hoveringHeader = $0 }
                .pikAnimation(Motion.quick, value: hoveringHeader)
                .pikAnimation(Motion.drawer, value: collapsed)
                .help(collapsed ? L("展开这一层（按住 ⌥ 点：全部展开）", "Expand this shelf (⌥-click: expand all)")
                                : L("收起这一层（按住 ⌥ 点：全部收起）", "Collapse this shelf (⌥-click: collapse all)"))
                if targeted {
                    Label(L("松手放进“\(shelf.name)”", "Drop to add to “\(shelf.name)”"), systemImage: "plus.circle.fill")
                        .font(.callout)
                        .foregroundStyle(Color.accentColor)
                }
            }
            // 内容一直在，只是高度在 0 和实际高度之间变化（像抽屉），下面的书架跟着平滑移动
                Group {
                    if shelf.items.isEmpty {
                        Text(L("这层还是空的。把文件拖到这里，或者在访达里放进“\(shelf.name)”文件夹。", "This shelf is empty. Drag files here, or put them in the “\(shelf.name)” folder in Finder."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 116, maximum: 116), spacing: 14, alignment: .top)],
                                  alignment: .leading, spacing: 14) {
                            ForEach(shelf.items) { item in
                                ShelfTile(item: item)
                            }
                        }
                        // 拖动、移进移出时，其他图标平滑让位
                        .pikAnimation(Motion.springy, value: shelf.items.map(\.id))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { contentHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, h in contentHeight = h }
                })
                // 先淡：收起时图标先很快淡掉，展开时等高度撑开了再淡入（不然会和下面的书架叠在一起）
                .opacity(collapsed ? 0 : 1)
                .pikAnimation(collapsed ? .easeOut(duration: 0.12) : .easeIn(duration: 0.18).delay(0.16), value: collapsed)
                // 再收高度：像抽屉一样
                // 收起时里面的图标不算拖放目标
                .transformPreference(TileFrameKey.self) { if collapsed { $0 = [:] } }
                .frame(height: collapsed ? 0 : contentHeight, alignment: .top)
                .clipShape(Rectangle()) // 超出当前高度的部分不画出来
                .allowsHitTesting(!collapsed)
                .padding(.top, collapsed ? -14 : 0) // 收起时把和标题之间的间距也收掉
                .pikAnimation(collapsed ? Motion.drawer.delay(0.06) : Motion.drawer, value: collapsed)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            collapsed = collapsedNames.contains(shelf.name) // 打开时按存的状态，不播动画
        }
        .onChange(of: collapsedRaw) { _, _ in
            let stored = collapsedNames.contains(shelf.name)
            if stored != collapsed { withPikAnimation(Motion.drawer) { collapsed = stored } } // 别的书架按 ⌥ 点了“全部收起 / 展开”
        }
        .background(GeometryReader { geo in
            Color.clear.preference(key: ShelfFrameKey.self, value: [shelf.url: geo.frame(in: .named("shelf"))])
        })
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(highlighted ? Color.accentColor.opacity(0.08) : .clear)
                .strokeBorder(highlighted ? Color.accentColor.opacity(0.6) : .clear, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        )
        .pikAnimation(Motion.quick, value: highlighted)
        .padding(-12) // 高亮框往外扩一点，内容位置不变
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            onImport(urls)
            return true
        } isTargeted: { targeted = $0 }
    }
}

/// 书架上的一个图标：浅色底 + 表情 + 文件名
struct ShelfTile: View {
    let item: ShelfItem
    @Environment(\.openWindow) private var openWindow
    @Environment(Library.self) private var library
    @Environment(ShelfDrag.self) private var drag
    @State private var hovering = false
    @State private var confirmingDelete = false
    @State private var renaming = false
    @State private var dropTargeted = false
    @State private var editing = false
    @State private var emoji = ""
    @State private var color = ShelfColor.gray
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                // 鼠标移上去：图标轻轻浮起（放大一点 + 一点影子）
                TileIcon(emoji: item.emoji, color: item.color)
                    .scaleEffect(hovering ? 1.05 : 1)
                    .shadow(color: .black.opacity(hovering ? 0.12 : 0), radius: hovering ? 8 : 0, y: hovering ? 4 : 0)
                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1.5)
                        .background(.gray, in: RoundedRectangle(cornerRadius: 4))
                        .offset(x: 4, y: 4)
                }
            }
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 104)
        }
        .padding(.vertical, 10)
        .frame(width: 116)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(hovering ? Color.primary.opacity(0.07) : .clear)
        )
        .overlay(alignment: .leading) {
            // 别的图标拖到这个图标上：放在它前面，左边一条蓝线提示
            if dropTargeted || drag.target == .before(item: item.url, folder: item.url.deletingLastPathComponent()) {
                RoundedRectangle(cornerRadius: 1.5).fill(Color.accentColor).frame(width: 3).padding(.vertical, 8).offset(x: -8)
            }
        }
        // 正在被拖走：原位置变淡
        .opacity(drag.item?.id == item.id ? 0.3 : 1)
        .background(GeometryReader { geo in
            Color.clear.preference(key: TileFrameKey.self, value: [item.url: geo.frame(in: .named("shelf"))])
        })
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .pikAnimation(Motion.quick, value: hovering)
        .pikAnimation(Motion.quick, value: dropTargeted)
        .pikAnimation(Motion.quick, value: drag.item?.id == item.id)
        .onTapGesture { OpenNotes.open(item.url, using: openWindow) } // 单击在新窗口打开
        // 按住拖：拖到别的书架上就移过去，拖到同一层的别的图标上就调整顺序（app 自己处理，见文件开头）
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("shelf"))
                .onChanged { value in
                    if drag.item == nil {
                        drag.item = item
                        // 记下按下的点离图标中心多远，影子跟着走时不会“跳”到鼠标正中
                        if let frame = drag.tileFrames[item.url] {
                            drag.grab = CGSize(width: value.startLocation.x - frame.midX, height: value.startLocation.y - frame.midY)
                        }
                    }
                    drag.location = value.location
                    let target = drag.target(at: value.location)
                    if target != drag.target { withPikAnimation(Motion.quick) { drag.target = target } }
                }
                .onEnded { value in
                    let target = drag.target(at: value.location)
                    // 影子消失、图标出现在新位置，都在同一瞬间，不播动画
                    withoutAnimation {
                        do {
                            switch target {
                            case let .before(other, folder): try library.place(item.url, in: folder, before: other)
                            case let .end(shelf): try library.place(item.url, in: shelf)
                            case nil: break
                            }
                        } catch { errorMessage = error.localizedDescription }
                        drag.item = nil
                        drag.target = nil
                    }
                }
        )
        .dropDestination(for: URL.self) { urls, _ in
            let folder = item.url.deletingLastPathComponent()
            do {
                // 拖放换位置：不播放让位动画（见 withoutAnimation 的说明）
                try withoutAnimation {
                    for url in urls where !url.isDirectory && url.standardizedFileURL != item.url.standardizedFileURL {
                        try library.place(url, in: folder, before: item.url)
                    }
                }
            } catch { errorMessage = error.localizedDescription }
            return true
        } isTargeted: { dropTargeted = $0 }
        .help(item.url.lastPathComponent)
        .contextMenu {
            Button(L("打开", "Open")) { OpenNotes.open(item.url, using: openWindow) }
            Button(L("改图标和底色…", "Change Icon and Color…")) {
                emoji = item.emoji
                color = item.color
                editing = true
            }
            Button(L("重命名…", "Rename…")) { renaming = true }
            Button(L("在访达中显示", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Divider()
            Button(L("移到废纸篓…", "Move to Trash…"), role: .destructive) { confirmingDelete = true }
        }
        .renameFileAlert(item.url, isPresented: $renaming)
        // 改图标和底色：和书架管理里一样的小窗，关掉时保存
        .popover(isPresented: $editing, arrowEdge: .bottom) {
            HStack(alignment: .top, spacing: 20) {
                LiveTileIcon(emoji: emoji, color: color, size: 72)
                AppearancePicker(emoji: $emoji, color: $color)
            }
            .padding(18)
            .onDisappear {
                if emoji != item.emoji || color != item.color {
                    do { try library.setAppearance(of: item.url, emoji: emoji, color: color) } catch { errorMessage = error.localizedDescription }
                }
            }
        }
        .confirmationDialog(L("把“\(item.title)”移到废纸篓？", "Move “\(item.title)” to the Trash?"), isPresented: $confirmingDelete) {
            Button(L("移到废纸篓", "Move to Trash"), role: .destructive) {
                do { try library.trashFile(item.url) } catch { errorMessage = error.localizedDescription }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("删错了可以从废纸篓里拿回来。", "You can get it back from the Trash."))
        }
        .alert(L("出了点问题", "Something Went Wrong"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(L("好", "OK")) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

/// 第一次打开：还没选根文件夹
struct WelcomeView: View {
    @Environment(Library.self) private var library

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
            Text(L("欢迎使用拾记", "Welcome to PikNote")).font(.title.bold())
            Text(L("先选一个文件夹放笔记。\n里面的每个子文件夹就是一层书架，每篇笔记都是普通的 .md 文件。", "First, choose a folder for your notes.\nEach subfolder becomes a shelf, and every note is a plain .md file."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(L("选择笔记文件夹…", "Choose Notes Folder…")) { library.chooseRoot() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 根文件夹里还没有子文件夹
struct EmptyShelfView: View {
    @Environment(Library.self) private var library

    var body: some View {
        VStack(spacing: 14) {
            Text("📚").font(.system(size: 56))
            Text(L("书架还是空的", "Your bookshelf is empty")).font(.title2.bold())
            Text(L("在笔记文件夹里新建一个子文件夹，就会多一层书架。", "Create a subfolder in your notes folder to add a shelf."))
                .foregroundStyle(.secondary)
            Button(L("在访达中打开笔记文件夹", "Open Notes Folder in Finder")) {
                if let root = library.rootURL { NSWorkspace.shared.open(root) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 拖动时跟着鼠标的影子：和书架上的图标长得一样，稍微浮起
private struct DragGhost: View {
    let item: ShelfItem
    var body: some View {
        VStack(spacing: 10) {
            TileIcon(emoji: item.emoji, color: item.color)
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 104)
        }
        .padding(.vertical, 10)
        .frame(width: 116)
        .scaleEffect(1.05)
    }
}
