// 书架管理：分“书架上”和“书架外（归档）”两区，拖动即可移入移出。
// 还能：调整顺序、改图标和底色、新建或重命名一层书架；
// 列出“未放上书架”的散落文件和被忽略的子文件夹。
// 移出书架 = 移到“归档”文件夹，文件不删除。
import SwiftUI

struct ShelfManager: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                onShelf
                    .frame(minWidth: 380, idealWidth: 500)
                archivePanel
                    .frame(minWidth: 240, idealWidth: 300)
            }
            Divider()
            footer
        }
        .frame(width: 860, height: 620)
    }

    // MARK: 顶部

    private var header: some View {
        HStack {
            Text(L("书架管理", "Manage Shelves")).font(.title2.bold())
            Spacer()
            Button {
                attempt {
                    let url = try library.createShelf(named: L("新书架", "New Shelf"))
                    renaming = url // 新建后直接进入改名
                }
            } label: {
                Label(L("新建一层", "New Shelf"), systemImage: "plus")
            }
            Button {
                addFiles()
            } label: {
                Label(L("添加文件…", "Add Files…"), systemImage: "doc.badge.plus")
            }
            .disabled(library.shelves.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var footer: some View {
        HStack {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else {
                Text(L("拖动调整顺序 · 拖到右边移出书架 · 也可以从访达把文件拖进来（会复制一份）", "Drag to reorder · Drag right to archive · Drag files in from Finder (they’re copied)"))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L("完成", "Done")) { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .font(.callout)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: 左边：书架上

    private var onShelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L("书架上", "On Shelves")).font(.headline).foregroundStyle(.secondary)
                ForEach(library.shelves) { shelf in
                    ShelfSection(shelf: shelf, renaming: $renaming, attempt: attempt)
                }
                if library.shelves.isEmpty {
                    Text(L("还没有书架。点右上角“新建一层”。", "No shelves yet. Click “New Shelf” at the top right.")).foregroundStyle(.secondary)
                }
                if !library.looseFiles.isEmpty || !library.ignoredFolders.isEmpty {
                    unshelved
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 未放上书架的散落文件、被忽略的子文件夹
    private var unshelved: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 4)
            if !library.looseFiles.isEmpty {
                Text(L("未放上书架", "Not on a Shelf")).font(.headline).foregroundStyle(.secondary)
                Text(L("这些文件直接放在笔记文件夹里，不在任何一层上。拖到某层，或者用右边的菜单放上去。", "These files sit directly in your notes folder, not on any shelf. Drag them onto a shelf, or use the menu on the right."))
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(library.looseFiles, id: \.self) { file in
                    HStack {
                        TileIcon(emoji: Library.defaultEmoji(for: file), color: .gray, size: 26)
                        Text(file.lastPathComponent).lineLimit(1)
                        Spacer()
                        Menu(L("放到…", "Move to…")) {
                            ForEach(library.shelves) { shelf in
                                Button(shelf.name) { attempt { try library.place(file, in: shelf.url) } }
                            }
                        }
                        .fixedSize()
                    }
                    .padding(.vertical, 2)
                    .draggable(file)
                }
            }
            if !library.ignoredFolders.isEmpty {
                Text(L("被忽略的子文件夹", "Ignored Subfolders")).font(.headline).foregroundStyle(.secondary).padding(.top, 6)
                Text(L("拾记的书架只有一层，书架里的子文件夹不会显示。里面的文件都还在。", "PikNote shelves are one level deep, so subfolders inside a shelf aren’t shown. Their files are still there."))
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(library.ignoredFolders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "folder").foregroundStyle(.secondary)
                        Text(library.rootURL.map { Library.relativePath(of: folder, in: $0) } ?? folder.lastPathComponent)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L("在访达中显示", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                            .buttonStyle(.link)
                    }
                    .font(.callout)
                }
            }
        }
    }

    // MARK: 右边：书架外（归档）

    @State private var archiveTargeted = false

    private var archivePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("书架外（归档）", "Off the Shelf (Archive)")).font(.headline).foregroundStyle(.secondary)
            Text(L("拖到这里 = 移出书架。文件不会删除，放在“\(Library.archiveName)”文件夹里，也不参与搜索。把书架标题拖过来，就是整层归档。", "Drop here to take files off the shelf. Nothing is deleted: files go into the “\(Library.archiveName)” folder and are left out of search. Drag a shelf title here to archive the whole shelf."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(library.archivedShelves) { shelf in
                        ArchivedShelfGroup(shelf: shelf, attempt: attempt)
                    }
                    ForEach(library.archive) { item in
                        ItemRow(item: item, folder: library.archiveURL!, attempt: attempt)
                    }
                    if library.archive.isEmpty && library.archivedShelves.isEmpty {
                        Text(L("归档是空的", "The archive is empty"))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(archiveTargeted ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
        .dropDestination(for: URL.self) { urls, _ in
            guard let archive = library.archiveURL else { return false }
            attempt {
                for url in urls {
                    if library.shelves.contains(where: { $0.url.standardizedFileURL.path == url.standardizedFileURL.path }) {
                        try library.archiveShelf(url) // 拖过来的是整层书架
                    } else if !url.isDirectory {
                        try library.place(url, in: archive)
                    }
                }
            }
            return true
        } isTargeted: { archiveTargeted = $0 }
    }

    // MARK: 添加文件

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = L("选择要放上书架的文件（会复制一份到书架里，原文件不动）", "Choose files to add (copies go on the shelf; the originals stay put)")
        panel.prompt = L("添加", "Add")
        // 让用户选放在哪层
        let picker = NSPopUpButton()
        library.shelves.forEach { picker.addItem(withTitle: $0.name) }
        let label = NSTextField(labelWithString: L("放在：", "Shelf:"))
        let stack = NSStackView(views: [label, picker])
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        panel.accessoryView = stack
        panel.isAccessoryViewDisclosed = true
        guard panel.runModal() == .OK else { return }
        let shelf = library.shelves[max(0, picker.indexOfSelectedItem)]
        attempt { for url in panel.urls { try library.place(url, in: shelf.url) } }
    }

    /// 执行一个可能失败的操作，失败就在底部显示原因
    private func attempt(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 一层书架

private struct ShelfSection: View {
    let shelf: Shelf
    @Binding var renaming: URL?
    let attempt: (() throws -> Void) -> Void
    @Environment(Library.self) private var library
    @State private var newName = ""
    @State private var targeted = false
    @State private var headerTargeted = false
    @State private var confirmingDelete = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .help(L("拖动调整书架顺序", "Drag to reorder shelves"))
                if renaming == shelf.url {
                    TextField(L("书架名字", "Shelf name"), text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .focused($nameFocused)
                        .onSubmit(commitRename)
                        .onExitCommand { renaming = nil }
                        .onAppear { newName = shelf.name; nameFocused = true }
                } else {
                    Text(shelf.name)
                        .font(.system(size: 15, weight: .semibold))
                        .onTapGesture(count: 2) { renaming = shelf.url }
                }
                Text("\(shelf.items.count)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button(L("重命名", "Rename")) { renaming = shelf.url }
                    Button(L("整层归档", "Archive Shelf")) { attempt { try library.archiveShelf(shelf.url) } }
                    Divider()
                    Button(L("在访达中显示", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([shelf.url]) }
                    Button(L("删除书架…", "Delete Shelf…"), role: .destructive) { confirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.vertical, 4)
            .overlay(alignment: .top) {
                if headerTargeted { Rectangle().fill(Color.accentColor).frame(height: 2).offset(y: -6) }
            }
            .contentShape(Rectangle())
            .draggable(shelf.url) {
                Label(shelf.name, systemImage: "books.vertical").padding(6)
            }
            // 拖一层书架到这里：排到这层前面；拖文件到标题上：放进这层末尾
            .dropDestination(for: URL.self) { urls, _ in
                attempt {
                    for url in urls {
                        if library.shelves.contains(where: { $0.url.standardizedFileURL.path == url.standardizedFileURL.path }) {
                            try library.moveShelf(url, before: shelf.url)
                        } else if library.archivedShelves.contains(where: { $0.url.standardizedFileURL.path == url.standardizedFileURL.path }) {
                            try library.restoreShelf(url, before: shelf.url)
                        } else if !url.isDirectory {
                            try library.place(url, in: shelf.url)
                        }
                    }
                }
                return true
            } isTargeted: { headerTargeted = $0 }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(shelf.items) { item in
                    ItemRow(item: item, folder: shelf.url, attempt: attempt)
                }
                if shelf.items.isEmpty {
                    Text(L("空的，把文件拖到这里", "Empty. Drag files here."))
                        .font(.callout).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(targeted ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
            )
            // 拖到这层的空白处：放到最后
            .dropDestination(for: URL.self) { urls, _ in
                attempt { for url in urls where !url.isDirectory { try library.place(url, in: shelf.url) } }
                return true
            } isTargeted: { targeted = $0 }
        }
        .confirmationDialog(L("把书架“\(shelf.name)”整层移到废纸篓？", "Move the shelf “\(shelf.name)” to the Trash?"), isPresented: $confirmingDelete) {
            Button(L("移到废纸篓", "Move to Trash"), role: .destructive) { attempt { try library.trashShelf(shelf.url) } }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            let count = Library.fileCount(in: shelf.url)
            Text(count == 0
                 ? L("这层是空的。", "This shelf is empty.")
                 : L("里面的 \(count) 个文件会一起移到废纸篓，删错了可以从废纸篓里拿回来。如果只是不想放在书架上，可以用“整层归档”。",
                     "Its \(count) files go to the Trash too. You can get them back from the Trash. To just take it off the bookshelf, use “Archive Shelf” instead."))
        }
    }

    private func commitRename() {
        let name = newName
        renaming = nil
        attempt { try library.renameShelf(shelf.url, to: name) }
    }
}

// MARK: - 一个文件

private struct ItemRow: View {
    let item: ShelfItem
    /// 这个文件现在所在的文件夹（某层书架或归档）
    let folder: URL
    let attempt: (() throws -> Void) -> Void
    @Environment(Library.self) private var library
    @State private var editing = false
    @State private var emoji = ""
    @State private var color = ShelfColor.gray
    @State private var targeted = false
    @State private var hovering = false
    @State private var confirmingDelete = false

    private var inArchive: Bool { library.isArchived(folder) }

    var body: some View {
        HStack(spacing: 10) {
            TileIcon(emoji: item.emoji, color: item.color, size: 28)
            Text(item.title).lineLimit(1)
            if let badge = item.badge {
                Text(badge).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
            Spacer()
            if hovering {
                Button(L("改图标", "Change Icon")) { startEditing() }
                    .buttonStyle(.link).font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.05) : .clear))
        .overlay(alignment: .top) {
            // 拖到这一行上：放在这一行前面，用一条蓝线提示
            if targeted { Rectangle().fill(Color.accentColor).frame(height: 2).offset(y: -1) }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .draggable(item.url) {
            HStack { TileIcon(emoji: item.emoji, color: item.color, size: 28); Text(item.title) }.padding(6)
        }
        .dropDestination(for: URL.self) { urls, _ in
            attempt { for url in urls where !url.isDirectory && url != item.url { try library.place(url, in: folder, before: item.url) } }
            return true
        } isTargeted: { targeted = $0 }
        .contextMenu {
            Button(L("改图标和底色…", "Change Icon and Color…")) { startEditing() }
            if inArchive {
                Menu(L("放回书架", "Put Back on Shelf")) {
                    ForEach(library.shelves) { shelf in
                        Button(shelf.name) { attempt { try library.place(item.url, in: shelf.url) } }
                    }
                }
            } else {
                Button(L("移出书架（放进归档）", "Take Off Shelf (Archive)")) {
                    attempt { if let archive = library.archiveURL { try library.place(item.url, in: archive) } }
                }
                Menu(L("移到", "Move To")) {
                    ForEach(library.shelves.filter { $0.url != folder }) { shelf in
                        Button(shelf.name) { attempt { try library.place(item.url, in: shelf.url) } }
                    }
                }
            }
            Divider()
            Button(L("在访达中显示", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Button(L("移到废纸篓…", "Move to Trash…"), role: .destructive) { confirmingDelete = true }
        }
        .confirmationDialog(L("把“\(item.title)”移到废纸篓？", "Move “\(item.title)” to the Trash?"), isPresented: $confirmingDelete) {
            Button(L("移到废纸篓", "Move to Trash"), role: .destructive) { attempt { try library.trashFile(item.url) } }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("删错了可以从废纸篓里拿回来。", "You can get it back from the Trash."))
        }
        .popover(isPresented: $editing, arrowEdge: .trailing) {
            HStack(alignment: .top, spacing: 20) {
                TileIcon(emoji: emoji, color: color, size: 72)
                AppearancePicker(emoji: $emoji, color: $color)
            }
            .padding(18)
            .onDisappear {
                // 关掉小窗时保存
                if emoji != item.emoji || color != item.color {
                    attempt { try library.setAppearance(of: item.url, emoji: emoji, color: color) }
                }
            }
        }
    }

    private func startEditing() {
        emoji = item.emoji
        color = item.color
        editing = true
    }
}

// MARK: - 整层归档的书架

private struct ArchivedShelfGroup: View {
    let shelf: Shelf
    let attempt: (() throws -> Void) -> Void
    @Environment(Library.self) private var library
    @State private var expanded = true
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Button { expanded.toggle() } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
                Text("📦 \(shelf.name)").font(.system(size: 13, weight: .semibold))
                Text("\(shelf.items.count)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L("放回书架", "Put Back on Shelf")) { attempt { try library.restoreShelf(shelf.url) } }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .help(L("整层归档的书架。拖到左边的书架标题上，也能放回", "An archived shelf. You can also drag it onto a shelf title on the left to put it back."))
            .draggable(shelf.url) {
                Label(shelf.name, systemImage: "archivebox").padding(6)
            }
            .contextMenu {
                Button(L("放回书架", "Put Back on Shelf")) { attempt { try library.restoreShelf(shelf.url) } }
                Button(L("在访达中显示", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([shelf.url]) }
            }

            if expanded {
                ForEach(shelf.items) { item in
                    ItemRow(item: item, folder: shelf.url, attempt: attempt)
                        .padding(.leading, 14)
                }
                if shelf.items.isEmpty {
                    Text(L("空的", "Empty")).font(.caption).foregroundStyle(.tertiary).padding(.leading, 26)
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 8).fill(targeted ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03)))
        .padding(.bottom, 6)
        // 文件拖到这一组上：放进这层归档的书架
        .dropDestination(for: URL.self) { urls, _ in
            attempt { for url in urls where !url.isDirectory { try library.place(url, in: shelf.url) } }
            return true
        } isTargeted: { targeted = $0 }
    }
}
