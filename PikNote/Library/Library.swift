// 书架的数据：读取根文件夹，一个子文件夹就是一层书架。
import SwiftUI

/// 书架上的一个文件
struct ShelfItem: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    var emoji: String
    var color: ShelfColor

    /// 显示用的名字：.md 不显示扩展名，其他文件也去掉扩展名（右下角有类型角标）
    var title: String { url.deletingPathExtension().lastPathComponent }
    var isMarkdown: Bool { url.pathExtension.lowercased() == "md" }
    /// 非 .md 文件右下角的类型角标，比如 PDF
    var badge: String? { isMarkdown ? nil : url.pathExtension.uppercased() }
}

/// 一层书架
struct Shelf: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    var name: String { url.lastPathComponent }
    var items: [ShelfItem]
}

/// 图标的底色：8 种预设的浅色（和设计稿一致），也可以是自己挑的任意颜色（存成 "#RRGGBB"）。
/// shelf.json 里就是一个字符串："blue" 或 "#F2D7E0"，以前存的文件不用改
struct ShelfColor: Hashable, RawRepresentable, Codable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }

    static let blue = ShelfColor(rawValue: "blue")
    static let peach = ShelfColor(rawValue: "peach")
    static let green = ShelfColor(rawValue: "green")
    static let lavender = ShelfColor(rawValue: "lavender")
    static let cream = ShelfColor(rawValue: "cream")
    static let teal = ShelfColor(rawValue: "teal")
    static let pink = ShelfColor(rawValue: "pink")
    static let gray = ShelfColor(rawValue: "gray")
    /// 预设的 8 种（选颜色那一排）
    static let allCases: [ShelfColor] = [.blue, .peach, .green, .lavender, .cream, .teal, .pink, .gray]

    private static let presets: [String: (Double, Double, Double)] = [
        "blue": (0.902, 0.933, 0.980), "peach": (0.976, 0.914, 0.882), "green": (0.898, 0.953, 0.910),
        "lavender": (0.929, 0.906, 0.973), "cream": (0.973, 0.937, 0.867), "teal": (0.882, 0.937, 0.945),
        "pink": (0.965, 0.890, 0.902), "gray": (0.933, 0.933, 0.949),
    ]

    /// 是预设的那 8 种之一吗（不是就是自己挑的颜色）
    var isPreset: Bool { Self.presets[rawValue] != nil }

    var color: Color {
        if let (r, g, b) = Self.presets[rawValue] { return Color(red: r, green: g, blue: b) }
        return Color(hex: rawValue) ?? Color(red: 0.933, green: 0.933, blue: 0.949)
    }

    /// 自己挑的颜色
    init?(custom color: Color) {
        guard let hex = color.hexString else { return nil }
        self.init(rawValue: hex)
    }

    // 存成一个字符串（不是 {"rawValue": …}），和以前的文件一样
    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// 没设置过底色时，按名字固定挑一种，保证每次打开颜色都一样
    static func stable(for name: String) -> ShelfColor {
        let sum = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return allCases[sum % allCases.count]
    }
}

@Observable
final class Library {
    static let archiveName = "归档"
    private static let rootKey = "rootPath"

    private(set) var rootURL: URL?
    private(set) var shelves: [Shelf] = []
    /// 书架窗口是否显示“新建笔记”面板（菜单 ⌘N 和右上角按钮都改它）
    var showingNewNote = false
    /// 书架窗口是否显示“书架管理”面板
    var showingManager = false
    @ObservationIgnored private var watcher: FolderWatcher?

    init() {
        if let path = UserDefaults.standard.string(forKey: Self.rootKey),
           FileManager.default.fileExists(atPath: path) {
            setRoot(URL(fileURLWithPath: path, isDirectory: true))
        }
    }

    /// 弹出对话框让用户选根文件夹
    func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L("选择", "Choose")
        panel.message = L("选一个文件夹放笔记。可以放在 iCloud 云盘、OneDrive 等任何同步文件夹里。", "Choose a folder for your notes. It can be in iCloud Drive, OneDrive, or any synced folder.")
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: Self.rootKey)
            setRoot(url)
            seedTutorialIfEmpty() // 选的是空文件夹：建一层书架，放上使用教程
        }
    }

    private func setRoot(_ url: URL) {
        // 用硬盘上真正的路径（大小写、软链接都以硬盘为准）。
        // Mac 的文件名不分大小写，“piknote资料”也能打开“PikNote资料”，
        // 但书架是按路径一个字一个字比对来找表情和底色的，大小写不一致就全对不上。
        let url = Self.canonical(url)
        UserDefaults.standard.set(url.path, forKey: Self.rootKey)
        rootURL = url
        reload()
        // 访达里新建文件夹、放进文件、云盘同步过来的修改，都会触发刷新
        watcher = FolderWatcher(url: url) { [weak self] paths in
            self?.reload()
            NotificationCenter.default.post(name: .piknoteFilesChanged, object: nil, userInfo: ["paths": paths])
        }
    }

    /// 重新扫描根文件夹
    func reload() {
        guard let rootURL else {
            shelves = []; archive = []; archivedShelves = []; looseFiles = []; ignoredFolders = []
            return
        }
        let settings = ShelfSettings.load(root: rootURL)
        let children = Self.visibleChildren(of: rootURL)
        let folders = children.filter(\.isDirectory)

        func items(in folder: URL) -> [ShelfItem] {
            let files = Self.visibleChildren(of: folder).filter { !$0.isDirectory } // 子文件夹不显示（设计如此）
            return ShelfSettings.sorted(files, by: settings.order?[Self.orderKey(folder, root: rootURL)]).map { file in
                let saved = settings.items[Self.relativePath(of: file, in: rootURL)]
                return ShelfItem(
                    url: file,
                    emoji: saved?.emoji ?? Self.defaultEmoji(for: file),
                    color: saved?.color ?? .stable(for: file.lastPathComponent)
                )
            }
        }

        let shelfFolders = ShelfSettings.sorted(folders.filter { $0.lastPathComponent != Self.archiveName }, by: settings.shelves)
        shelves = shelfFolders.map { Shelf(url: $0, items: items(in: $0)) }
        let archiveFolder = rootURL.appendingPathComponent(Self.archiveName)
        archive = items(in: archiveFolder)
        // 归档里的文件夹：整层归档的书架
        let archivedFolders = Self.visibleChildren(of: archiveFolder).filter(\.isDirectory)
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        archivedShelves = archivedFolders.map { Shelf(url: $0, items: items(in: $0)) }
        looseFiles = children.filter { !$0.isDirectory }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        // 书架里的子文件夹不显示；其中 assets 是放笔记图片的附件文件夹，是正常的，不用提醒
        ignoredFolders = (shelfFolders + archivedFolders)
            .flatMap { Self.visibleChildren(of: $0).filter { $0.isDirectory && $0.lastPathComponent != "assets" } }
    }

    /// 整层归档的书架（“归档”里的文件夹）
    private(set) var archivedShelves: [Shelf] = []

    /// 在 shelf.json 里记顺序用的名字：书架就是“课程”，整层归档的是“归档/课程”
    static func orderKey(_ folder: URL, root: URL) -> String {
        relativePath(of: folder, in: root)
    }

    /// 某个文件夹（书架、归档、整层归档的书架）现在显示的文件
    private func displayedItems(in folder: URL) -> [ShelfItem] {
        let path = folder.standardizedFileURL.path
        if path == archiveURL?.standardizedFileURL.path { return archive }
        return (shelves + archivedShelves).first { $0.url.standardizedFileURL.path == path }?.items ?? []
    }

    /// 这个文件夹是不是在“归档”里（归档本身，或整层归档的书架）
    func isArchived(_ folder: URL) -> Bool {
        guard let archive = archiveURL?.standardizedFileURL.path else { return false }
        let path = folder.standardizedFileURL.path
        return path == archive || path.hasPrefix(archive + "/")
    }

    /// 书架外：“归档”文件夹里的文件
    private(set) var archive: [ShelfItem] = []
    /// 根文件夹里直接放着、不在任何一层上的文件
    private(set) var looseFiles: [URL] = []
    /// 书架里的子文件夹（软件不支持，只是列出来提示一下）
    private(set) var ignoredFolders: [URL] = []

    var archiveURL: URL? { rootURL?.appendingPathComponent(Self.archiveName) }

    /// 找某个文件在书架上的样子（编辑窗口标题要用表情）
    func item(for url: URL) -> ShelfItem? {
        shelves.lazy.flatMap(\.items).first { $0.url.standardizedFileURL == url.standardizedFileURL }
    }

    // MARK: - 新建笔记

    /// 在某层书架里新建一篇 .md，记下表情和底色，返回新文件的位置
    func createNote(name: String, emoji: String, color: ShelfColor, in shelf: Shelf) throws -> URL {
        guard let rootURL else { throw CocoaError(.fileNoSuchFile) }
        let title = Self.cleanName(name)
        let url = Self.uniqueURL(for: title, in: shelf.url)
        // 只写一行标题，方便以后大纲里有东西；用别的软件打开也是正常的 Markdown
        try "# \(title)\n".write(to: url, atomically: true, encoding: .utf8)
        try ShelfSettings.setItem(.init(emoji: emoji, color: color),
                                  for: Self.relativePath(of: url, in: rootURL), root: rootURL)
        reload()
        return url
    }

    // MARK: - 书架管理

    /// 把文件放到某层（或归档）里，排在 before 前面；before 为空就放最后。
    /// 同一层里拖动只改顺序；跨层就真的移动文件（重名自动加后缀）；
    /// 从根文件夹外面拖进来的文件，复制一份进来（原文件不动）。
    @discardableResult
    func place(_ file: URL, in folder: URL, before: URL? = nil) throws -> URL {
        guard let rootURL else { throw CocoaError(.fileNoSuchFile) }
        let source = file.standardizedFileURL
        let destFolder = folder.standardizedFileURL
        var target = source
        let rootPrefix = rootURL.standardizedFileURL.path + "/"

        if source.deletingLastPathComponent().path != destFolder.path {
            try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
            target = Self.uniqueDestination(for: source.lastPathComponent, in: destFolder)
            if source.path.hasPrefix(rootPrefix) {
                // 打开着的笔记先存好、关掉窗口，免得它往旧位置写
                OpenNotes.prepareToMove(source)
                try FileManager.default.moveItem(at: source, to: target)
            } else {
                try FileManager.default.copyItem(at: source, to: target)
            }
        }

        // 记下新顺序；文件换了位置，表情和底色也跟着搬过去
        let shelfName = Self.orderKey(destFolder, root: rootURL)
        let current = displayedItems(in: destFolder).map(\.url.lastPathComponent)
        try ShelfSettings.update(root: rootURL) { settings in
            let oldKey = Self.relativePath(of: source, in: rootURL)
            let newKey = Self.relativePath(of: target, in: rootURL)
            if oldKey != newKey, let saved = settings.items.removeValue(forKey: oldKey) {
                settings.items[newKey] = saved
            }
            let fromInside = source.path.hasPrefix(rootPrefix)
            let sameFolder = source.deletingLastPathComponent().path == destFolder.path
            // 从原来那层的顺序里拿掉（外面拖进来的文件不用管）
            if fromInside, !sameFolder {
                settings.order?[Self.orderKey(source.deletingLastPathComponent(), root: rootURL)]?.removeAll { $0 == source.lastPathComponent }
            }
            // 目标层里先拿掉它自己（只在同层调整顺序时才有），再插到新位置
            var list = (settings.order?[shelfName] ?? current).filter { $0 != target.lastPathComponent }
            if let before, let i = list.firstIndex(of: before.lastPathComponent) {
                list.insert(target.lastPathComponent, at: i)
            } else {
                list.append(target.lastPathComponent)
            }
            settings.order = settings.order ?? [:]
            settings.order?[shelfName] = list
        }
        reload()
        return target
    }

    /// 从访达拖进书架窗口：把文件放进某层。文件夹跳过；已经在这层的不动。
    /// 返回一句给用户看的结果说明（全部顺利时返回 nil）。
    func importFiles(_ urls: [URL], into shelf: URL) -> String? {
        var skippedFolders: [String] = [], failed: [String] = []
        for url in urls {
            if url.isDirectory { skippedFolders.append(url.lastPathComponent); continue }
            if url.deletingLastPathComponent().standardizedFileURL.path == shelf.standardizedFileURL.path { continue }
            do { try place(url, in: shelf) } catch { failed.append("\(url.lastPathComponent)（\(error.localizedDescription)）") }
        }
        var notes: [String] = []
        if !skippedFolders.isEmpty {
            notes.append(L("文件夹不能放上书架，已跳过：\(skippedFolders.joined(separator: "、"))。书架只有一层，可以把里面的文件拖进来。", "Folders can’t go on a shelf and were skipped: \(skippedFolders.joined(separator: ", ")). Shelves are one level deep, so drag in the files inside instead."))
        }
        if !failed.isEmpty { notes.append(L("这些文件没能导入：\(failed.joined(separator: "、"))", "These files couldn’t be imported: \(failed.joined(separator: ", "))")) }
        return notes.isEmpty ? nil : notes.joined(separator: "\n\n")
    }

    /// 整层归档：把整个书架文件夹移进“归档”，表情、底色、顺序都跟着走
    @discardableResult
    func archiveShelf(_ shelf: URL) throws -> URL {
        guard let rootURL, let archiveURL else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: true)
        let target = Self.uniqueDestination(for: shelf.lastPathComponent, in: archiveURL)
        try moveFolder(shelf, to: target, root: rootURL) { settings, old, new in
            settings.shelves?.removeAll { $0 == old }
        }
        return target
    }

    /// 整层放回书架：把“归档”里的书架文件夹移回来，排在最后
    @discardableResult
    func restoreShelf(_ archived: URL, before: URL? = nil) throws -> URL {
        guard let rootURL else { throw CocoaError(.fileNoSuchFile) }
        var name = archived.lastPathComponent
        if name == Self.archiveName { name = "\(name) 书架" }
        let target = Self.uniqueDestination(for: name, in: rootURL)
        let currentNames = shelves.map(\.name)
        try moveFolder(archived, to: target, root: rootURL) { settings, _, new in
            var names = (settings.shelves ?? currentNames).filter { $0 != new }
            if let before, let i = names.firstIndex(of: before.lastPathComponent) { names.insert(new, at: i) } else { names.append(new) }
            settings.shelves = names
        }
        return target
    }

    /// 是一层书架（书架上的或整层归档的）吗
    func isShelfFolder(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return (shelves + archivedShelves).contains { $0.url.standardizedFileURL.path == path }
    }

    /// 某层后面那一层（没有就是 nil，表示最后）
    func shelf(after url: URL) -> URL? {
        guard let i = shelves.firstIndex(where: { $0.url.standardizedFileURL.path == url.standardizedFileURL.path }),
              i + 1 < shelves.count else { return nil }
        return shelves[i + 1].url
    }

    /// 把一层书架放到 before 前面（nil = 最后）：书架上的就是调整顺序，归档里的就是放回书架
    func putShelf(_ url: URL, before: URL?) throws {
        let path = url.standardizedFileURL.path
        if archivedShelves.contains(where: { $0.url.standardizedFileURL.path == path }) {
            try restoreShelf(url, before: before)
        } else if before?.standardizedFileURL.path != path {
            try moveShelf(url, before: before)
        }
    }

    /// 移动整个书架文件夹，并把 shelf.json 里属于它的设置一起改名
    private func moveFolder(_ folder: URL, to target: URL, root: URL,
                            extra: (inout ShelfSettings, _ oldKey: String, _ newKey: String) -> Void) throws {
        for file in Self.visibleChildren(of: folder) where !file.isDirectory { OpenNotes.prepareToMove(file) }
        let oldKey = Self.orderKey(folder, root: root)
        try FileManager.default.moveItem(at: folder, to: target)
        let newKey = Self.orderKey(target, root: root)
        try ShelfSettings.update(root: root) { settings in
            if let list = settings.order?.removeValue(forKey: oldKey) { settings.order?[newKey] = list }
            for (key, value) in settings.items where key.hasPrefix(oldKey + "/") {
                settings.items.removeValue(forKey: key)
                settings.items[newKey + key.dropFirst(oldKey.count)] = value
            }
            extra(&settings, oldKey, newKey)
        }
        reload()
    }

    // MARK: - 删除（移到废纸篓，删错了还能从废纸篓拿回来）

    /// 把一个文件移到废纸篓；表情、底色和顺序里的记录一起去掉
    func trashFile(_ file: URL) throws {
        guard let rootURL else { return }
        // 先算好设置里的名字再删：文件没了以后，系统算路径的方式可能不一样
        let key = Self.relativePath(of: file, in: rootURL)
        let folderKey = Self.orderKey(file.deletingLastPathComponent(), root: rootURL)
        OpenNotes.prepareToMove(file) // 正打开的先存好、关窗口
        try FileManager.default.trashItem(at: file, resultingItemURL: nil)
        try ShelfSettings.update(root: rootURL) { settings in
            settings.items.removeValue(forKey: key)
            settings.order?[folderKey]?.removeAll { $0 == file.lastPathComponent }
        }
        reload()
    }

    /// 把一整层书架（文件夹）移到废纸篓；它的设置一起去掉
    func trashShelf(_ shelf: URL) throws {
        guard let rootURL else { return }
        for file in Self.visibleChildren(of: shelf) where !file.isDirectory { OpenNotes.prepareToMove(file) }
        let key = Self.orderKey(shelf, root: rootURL)
        try FileManager.default.trashItem(at: shelf, resultingItemURL: nil)
        try ShelfSettings.update(root: rootURL) { settings in
            settings.shelves?.removeAll { $0 == key }
            settings.order?.removeValue(forKey: key)
            for itemKey in settings.items.keys where itemKey.hasPrefix(key + "/") { settings.items.removeValue(forKey: itemKey) }
        }
        reload()
    }

    /// 书架里一共有几个文件（包括子文件夹里的），删除前提示用
    static func fileCount(in folder: URL) -> Int {
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        return (walker?.allObjects as? [URL] ?? []).filter { !$0.isDirectory }.count
    }

    /// 调整书架的顺序：把 shelf 排到 before 前面（before 为空就放最后）
    func moveShelf(_ shelf: URL, before: URL?) throws {
        guard let rootURL else { return }
        var names = shelves.map(\.name).filter { $0 != shelf.lastPathComponent }
        if let before, let i = names.firstIndex(of: before.lastPathComponent) {
            names.insert(shelf.lastPathComponent, at: i)
        } else {
            names.append(shelf.lastPathComponent)
        }
        try ShelfSettings.update(root: rootURL) { $0.shelves = names }
        reload()
    }

    /// 新建一层书架（就是新建一个文件夹）
    @discardableResult
    func createShelf(named name: String) throws -> URL {
        guard let rootURL else { throw CocoaError(.fileNoSuchFile) }
        var title = Self.cleanName(name)
        if title == Self.archiveName || title == L("未命名", "Untitled") && name.trimmingCharacters(in: .whitespaces).isEmpty { title = L("新书架", "New Shelf") }
        let url = Self.uniqueDestination(for: title, in: rootURL)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        try ShelfSettings.update(root: rootURL) { settings in
            settings.shelves = (settings.shelves ?? shelves.map(\.name)) + [url.lastPathComponent]
        }
        reload()
        return url
    }

    /// 重命名一层书架（就是重命名文件夹），设置里的名字一起改
    func renameShelf(_ shelf: URL, to name: String) throws {
        guard let rootURL else { return }
        let title = Self.cleanName(name)
        guard title != shelf.lastPathComponent else { return }
        guard title != Self.archiveName else { throw ShelfError(L("“\(Self.archiveName)”是系统保留的名字", "“\(Self.archiveName)” is a reserved name")) }
        let target = rootURL.appendingPathComponent(title)
        guard !FileManager.default.fileExists(atPath: target.path) else { throw ShelfError(L("已经有一层叫“\(title)”了", "There’s already a shelf called “\(title)”")) }
        for item in shelves.first(where: { $0.url == shelf })?.items ?? [] { OpenNotes.prepareToMove(item.url) }
        try FileManager.default.moveItem(at: shelf, to: target)
        let old = shelf.lastPathComponent
        try ShelfSettings.update(root: rootURL) { settings in
            settings.shelves = settings.shelves?.map { $0 == old ? title : $0 }
            if let list = settings.order?.removeValue(forKey: old) { settings.order?[title] = list }
            for (key, value) in settings.items where key.hasPrefix(old + "/") {
                settings.items.removeValue(forKey: key)
                settings.items[title + key.dropFirst(old.count)] = value
            }
        }
        reload()
    }

    /// 重命名一个文件（扩展名不变）。表情、底色、在这层里的位置都跟着新名字走。返回新位置
    @discardableResult
    func renameFile(_ file: URL, to name: String) throws -> URL {
        guard let rootURL else { throw CocoaError(.fileNoSuchFile) }
        let source = file.standardizedFileURL
        let ext = source.pathExtension
        // 用户可能连扩展名一起打了（“笔记.md”），去掉，免得变成“笔记.md.md”
        var title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ext.isEmpty, title.lowercased().hasSuffix("." + ext.lowercased()) { title = String(title.dropLast(ext.count + 1)) }
        title = Self.cleanName(title)
        let folder = source.deletingLastPathComponent()
        let target = folder.appendingPathComponent(ext.isEmpty ? title : title + "." + ext).standardizedFileURL
        guard target.lastPathComponent != source.lastPathComponent else { return source }
        // 只改大小写（note → Note）时，磁盘认为是同一个文件，不算重名
        let onlyCase = target.path.lowercased() == source.path.lowercased()
        guard onlyCase || !FileManager.default.fileExists(atPath: target.path) else {
            throw ShelfError(L("这层里已经有一个叫“\(target.lastPathComponent)”的文件了", "There’s already a file called “\(target.lastPathComponent)” here"))
        }
        let oldKey = Self.relativePath(of: source, in: rootURL)
        let folderKey = Self.orderKey(folder, root: rootURL)
        OpenNotes.prepareToMove(source) // 正打开的先存好、关窗口
        try FileManager.default.moveItem(at: source, to: target)
        let newKey = Self.relativePath(of: target, in: rootURL)
        try ShelfSettings.update(root: rootURL) { settings in
            if let saved = settings.items.removeValue(forKey: oldKey) { settings.items[newKey] = saved }
            if let list = settings.order?[folderKey] {
                settings.order?[folderKey] = list.map { $0 == source.lastPathComponent ? target.lastPathComponent : $0 }
            }
        }
        reload()
        return target
    }

    /// 改一个文件的表情和底色
    func setAppearance(of file: URL, emoji: String, color: ShelfColor) throws {
        guard let rootURL else { return }
        try ShelfSettings.setItem(.init(emoji: emoji, color: color), for: Self.relativePath(of: file, in: rootURL), root: rootURL)
        reload()
    }

    /// 任何文件的不重名位置：“讲义.pdf”已存在就用“讲义 2.pdf”
    static func uniqueDestination(for name: String, in folder: URL) -> URL {
        var base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var url = folder.appendingPathComponent(name)
        var n = 2
        // 名字本身已经以“ 2”这样的数字结尾：接着往上数（“生活 2”→“生活 3”），不变成“生活 2 2”
        if let space = base.lastIndex(of: " "), let number = Int(base[base.index(after: space)...]),
           number > 1, space > base.startIndex {
            base = String(base[..<space])
            n = number + 1
        }
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        return url
    }

    /// 文件名里不能有 / 和 :，前后空格去掉；什么都没写就叫“未命名”
    static func cleanName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return cleaned.isEmpty ? L("未命名", "Untitled") : cleaned
    }

    /// 重名时自动加后缀：“笔记.md”已存在就用“笔记 2.md”
    static func uniqueURL(for title: String, in folder: URL) -> URL {
        var url = folder.appendingPathComponent(title + ".md")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(title) \(n).md")
            n += 1
        }
        return url
    }

    // MARK: - 小工具

    private static func visibleChildren(of folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return urls
    }

    /// 文件夹在硬盘上真正的路径
    static func canonical(_ url: URL) -> URL {
        if let path = (try? url.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return url.standardizedFileURL
    }

    static func relativePath(of url: URL, in root: URL) -> String {
        let full = url.standardizedFileURL.path, base = root.standardizedFileURL.path + "/"
        return full.hasPrefix(base) ? String(full.dropFirst(base.count)) : url.lastPathComponent
    }

    static func defaultEmoji(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "md": "📝"
        case "pdf": "📄"
        case "png", "jpg", "jpeg", "gif", "heic", "webp": "🖼️"
        case "doc", "docx", "pages": "📃"
        case "xls", "xlsx", "numbers", "csv": "📊"
        case "ppt", "pptx", "key": "📽️"
        default: "📎"
        }
    }
}

extension URL {
    var isDirectory: Bool {
        let values = try? resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }
}

extension Notification.Name {
    /// 根文件夹里有文件变了（userInfo["paths"] 是变化的路径）
    static let piknoteFilesChanged = Notification.Name("piknoteFilesChanged")
    /// 菜单“重命名…”或点状态栏里的文件名：object 是要重命名的笔记窗口（NSWindow）
    static let piknoteRenameNote = Notification.Name("piknoteRenameNote")
}

/// 书架管理里给用户看的错误
struct ShelfError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
