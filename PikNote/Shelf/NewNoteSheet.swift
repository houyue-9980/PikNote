// 新建笔记面板：左边大号图标预览，右边名称、图标、底色、放在哪层。
import SwiftUI

struct NewNoteSheet: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    private static let lastShelfKey = "lastNewNoteShelf"

    @State private var name = ""
    @State private var emoji = "📝"
    @State private var color = ShelfColor.green
    @State private var shelfURL: URL?
    @State private var errorMessage: String?
    @FocusState private var focus: Field?
    private enum Field { case name }

    private var shelf: Shelf? { library.shelves.first { $0.url == shelfURL } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 36) {
                preview
                form
            }
            .padding(.horizontal, 36)
            .padding(.top, 28)
            .padding(.bottom, 24)

            Divider()
            HStack {
                if let errorMessage {
                    Text(errorMessage).font(.callout).foregroundStyle(.red)
                }
                Spacer()
                Button(L("取消", "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("创建", "Create"), action: create)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(shelf == nil)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.bar)
        }
        .frame(width: 600)
        .onAppear {
            // 默认放在上次用的那层，没有就第一层
            let last = UserDefaults.standard.string(forKey: Self.lastShelfKey)
            shelfURL = library.shelves.first { $0.url.path == last }?.url ?? library.shelves.first?.url
            emoji = AppearancePicker.commonEmojis.randomElement() ?? "📝"
            color = ShelfColor.allCases.randomElement() ?? .green
            focus = .name
        }
    }

    // MARK: 左边：预览

    private var preview: some View {
        VStack(spacing: 12) {
            TileIcon(emoji: emoji, color: color, size: 120)
            Text(name.isEmpty ? L("未命名", "Untitled") : name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 140)
            Text(L("预览", "Preview")).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: 右边：表单

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("新建笔记", "New Note")).font(.title2.bold())

            field(L("名称", "Name")) {
                TextField(L("比如：化学实验记录", "e.g. Chemistry Lab Notes"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .name)
                    .onSubmit(create)
            }

            AppearancePicker(emoji: $emoji, color: $color)

            HStack(alignment: .top, spacing: 20) {
                field(L("放在", "Shelf")) {
                    if library.shelves.isEmpty {
                        Text(L("还没有书架，先在访达里新建一个文件夹", "No shelves yet. Create a folder in Finder first.")).font(.callout).foregroundStyle(.secondary)
                    } else {
                        Picker("", selection: $shelfURL) {
                            ForEach(library.shelves) { s in
                                Text(s.name).tag(Optional(s.url))
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                field(L("保存到", "Saved to")) {
                    Text(shelf.map { StatusBar.friendlyPath($0.url).replacingOccurrences(of: " / ", with: " › ") } ?? "—")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.head)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.callout).foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: 创建

    private func create() {
        guard let shelf else { return }
        do {
            let url = try library.createNote(name: name, emoji: emoji, color: color, in: shelf)
            UserDefaults.standard.set(shelf.url.path, forKey: Self.lastShelfKey)
            dismiss()
            OpenNotes.open(url, using: openWindow) // 创建后自动在新窗口打开
        } catch {
            errorMessage = L("创建失败：\(error.localizedDescription)", "Couldn’t create the note: \(error.localizedDescription)")
        }
    }
}

/// 书架图标：浅色圆角方块 + 表情（书架和新建面板共用）
struct TileIcon: View {
    let emoji: String
    let color: ShelfColor
    var size: CGFloat = 78
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            .fill(scheme == .dark ? color.color.opacity(0.3) : color.color) // 深色模式下淡一点
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .strokeBorder(scheme == .dark ? .white.opacity(0.1) : .black.opacity(0.06))
            )
            .frame(width: size, height: size)
            .overlay(Text(emoji).font(.system(size: size * 0.51)))
    }
}
