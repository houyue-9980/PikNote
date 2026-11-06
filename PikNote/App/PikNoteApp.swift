// 拾记 PikNote 的入口：一个书架窗口 + 每篇笔记一个独立窗口。
import SwiftUI

@main
struct PikNoteApp: App {
    @State private var library = Library()

    init() {
        AppearanceSettings.shared.apply() // 启动时就用上保存的主题
    }

    var body: some Scene {
        // 书架窗口：只有一个，启动时默认打开
        Window(L("拾记", "PikNote"), id: "shelf") {
            ShelfWindow()
                .environment(library)
        }
        .defaultSize(width: 930, height: 600)
        .commands {
            AppCommands(library: library)
            ZoomCommands()
        }

        // 笔记窗口：每个文件一个，同一个文件再点会回到已经打开的窗口
        WindowGroup(for: URL.self) { $url in
            if let url {
                NoteWindow(url: url)
                    .environment(library)
            }
        }
        .defaultSize(width: 930, height: 640)
        .restorationBehavior(.disabled) // 重新打开软件时不自动恢复上次的笔记窗口（不做“最近打开”）

        // 设置窗口：菜单栏 拾记 → 设置…（⌘,）
        Settings {
            SettingsView()
        }
    }
}

/// 菜单栏
struct AppCommands: Commands {
    let library: Library
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // 去掉系统默认的“新建窗口”，换成我们自己的
        CommandGroup(replacing: .newItem) {
            Button(L("新建笔记…", "New Note…")) {
                openWindow(id: "shelf") // 新建面板长在书架窗口上
                library.showingNewNote = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(library.rootURL == nil)
            Button(L("书架管理…", "Manage Shelves…")) {
                openWindow(id: "shelf")
                library.showingManager = true
            }
            .disabled(library.rootURL == nil)
            Button(L("库", "Library")) { openWindow(id: "shelf") }
                .keyboardShortcut("l", modifiers: [.command, .shift]) // ⌘0 留给“实际大小”
            Divider()
            Button(L("更换笔记文件夹…", "Change Notes Folder…")) { library.chooseRoot() }
        }
    }
}
