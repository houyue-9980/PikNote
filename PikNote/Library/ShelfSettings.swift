// 书架设置：存在根文件夹里的隐藏文件 .piknote/shelf.json，跟着云盘同步。
//
// 格式示例：
// {
//   "shelves": ["课程", "生活"],                         ← 书架的顺序
//   "order": { "课程": ["DS 120 课堂笔记.md", "讲义.pdf"] }, ← 每层里文件的顺序
//   "items": {
//     "课程/DS 120 课堂笔记.md": { "emoji": "📊", "color": "blue" }
//   }
// }
// 没写进顺序的书架和文件，排在后面，按名字排。
import Foundation

struct ShelfSettings: Codable {
    struct Item: Codable {
        var emoji: String?
        var color: ShelfColor?
    }

    var shelves: [String]?
    var order: [String: [String]]?
    var items: [String: Item] = [:]

    static func fileURL(root: URL) -> URL {
        root.appendingPathComponent(".piknote/shelf.json")
    }

    static func load(root: URL) -> ShelfSettings {
        (try? loadStrict(root: root)) ?? ShelfSettings()
    }

    /// 读取；文件存在但内容坏了就报错（这时不能写，免得把用户的设置覆盖掉）
    private static func loadStrict(root: URL) throws -> ShelfSettings {
        let url = fileURL(root: root)
        guard FileManager.default.fileExists(atPath: url.path) else { return ShelfSettings() }
        return try JSONDecoder().decode(ShelfSettings.self, from: Data(contentsOf: url))
    }

    /// 读出来、改一改、存回去
    static func update(root: URL, _ change: (inout ShelfSettings) -> Void) throws {
        var settings = try loadStrict(root: root)
        change(&settings)
        let url = fileURL(root: root)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        // 排好序、换好行，方便人看，也方便云盘和 git 比较
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }

    /// 改一个文件的表情和底色
    static func setItem(_ item: Item, for relativePath: String, root: URL) throws {
        try update(root: root) { $0.items[relativePath] = item }
    }

    /// 按保存的顺序排：在顺序表里的按顺序，其余的按名字排在后面
    static func sorted(_ urls: [URL], by order: [String]?) -> [URL] {
        let index = Dictionary((order ?? []).enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return urls.sorted { a, b in
            switch (index[a.lastPathComponent], index[b.lastPathComponent]) {
            case let (i?, j?): return i < j
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
            }
        }
    }
}
