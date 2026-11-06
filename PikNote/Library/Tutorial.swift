// 第一次使用：选了一个空文件夹做笔记文件夹时，建一层书架，放上中文和英文两篇使用教程。
import Foundation

enum Tutorial {
    static var shelfName: String { L("我的书架", "My Shelf") }
    /// 两篇教程：文件名、内容、图标、底色
    static let guides: [(file: String, markdown: String, emoji: String, color: ShelfColor)] = [
        ("拾记使用教程.md", chinese, "📖", .blue),
        ("PikNote Guide.md", english, "📘", .green),
    ]

    static let chinese = """
    # 欢迎使用拾记

    拾记是一个超轻量的 Mac 笔记软件。每篇笔记都是一个普通的 `.md` 文件，存在你选的文件夹里，用别的软件也能打开。

    ## 书架

    - 笔记文件夹里的**每个子文件夹就是一层书架**，这篇教程就在「我的书架」上
    - 主窗口右上角的 ✏️（⌘N）新建笔记，可以选表情、底色和放在哪层
    - 右上角的方格按钮打开书架管理：拖动调整顺序、新建或重命名书架、把笔记或整层书架移进归档
    - 从访达把文件拖进主窗口，就能放上书架（会复制一份）

    ## 写笔记

    所见即所得，也可以直接打 Markdown：

    - 行首打 `#` 加空格是标题，`-` 加空格是列表
    - ⌘B 加粗，⌘I 斜体，⌘⇧H ==高亮==
    - 左边的大纲点一下就跳过去，小三角可以折叠
    - ⌘ + 点击链接，可以打开网址、其他笔记或 PDF

    点一下前面的小方框，就能勾选待办：

    - [ ] 试着勾选这个待办

    ## 公式

    按 **⌘⇧M** 打开公式快捷栏，搜「定积分」「fangcha」「matrix」都行，回车插入，Tab 跳到下一个空。

    也可以直接打：$E = mc^2$

    $$
    \\int_{a}^{b} f(x)\\,dx
    $$

    双击公式可以修改。

    ## 图片

    - 把图片拖进笔记，或者截图后按 ⌘V 粘贴
    - 选中图片，按 ⌘+ / ⌘- 调大小
    - 图片存在这层书架的 assets 文件夹里，不会出现在书架上

    ## 其他

    - ⌘+ / ⌘- / ⌘0 缩放页面
    - ⌘, 打开设置：语言、外观（浅色 / 深色 / 护眼）、个性化（标题颜色、底色、字体、行间距）
    - 笔记会自动保存，不用按 ⌘S

    读完可以把这篇教程删掉，或者在书架管理里移进归档。

    """

    static let english = """
    # Welcome to PikNote

    PikNote is a lightweight Mac note app. Every note is a plain `.md` file in the folder you chose, so other apps can open it too.

    ## Bookshelf

    - **Each subfolder of your notes folder is a shelf.** This guide sits on “My Shelf”
    - Click ✏️ at the top right of the main window (⌘N) to create a note and pick its emoji, color, and shelf
    - The grid button at the top right opens Manage Shelves: drag to reorder, create or rename shelves, and move notes or whole shelves into the archive
    - Drag files from Finder into the main window to put them on a shelf (they’re copied)

    ## Writing

    What you see is what you get, and Markdown works too:

    - Start a line with `#` and a space for a heading, `-` and a space for a list
    - ⌘B bold, ⌘I italic, ⌘⇧H ==highlight==
    - Click a heading in the outline on the left to jump to it; the small triangles fold sections
    - ⌘-click a link to open a website, another note, or a PDF

    Click the little box to check off a to-do:

    - [ ] Try checking this to-do

    ## Math

    Press **⌘⇧M** to open the formula bar. Search for “integral”, “matrix”, or “variance”, press Return to insert, and Tab to the next blank.

    You can also type it: $E = mc^2$

    $$
    \\int_{a}^{b} f(x)\\,dx
    $$

    Double-click a formula to edit it.

    ## Images

    - Drag images into a note, or take a screenshot and paste with ⌘V
    - Select an image and press ⌘+ / ⌘- to resize it
    - Images are saved in the shelf’s assets folder and don’t clutter the shelf

    ## More

    - ⌘+ / ⌘- / ⌘0 zoom the page
    - ⌘, opens Settings: language, appearance (Light / Dark / Sepia), and personalization (heading colors, background, font, line spacing)
    - Notes save automatically, no need for ⌘S

    When you’re done, delete this guide or move it to the archive in Manage Shelves.

    """
}

extension Library {
    /// 笔记文件夹是空的（没有书架、也没有散放的文件）：建一层书架，放上中英文两篇使用教程
    func seedTutorialIfEmpty() {
        guard let rootURL else { return }
        let visible = (try? FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        guard visible.isEmpty else { return }
        do {
            let shelf = try createShelf(named: Tutorial.shelfName)
            // 当前界面语言的那篇排在前面
            let guides = Lang.shared.isEnglish ? Tutorial.guides.reversed() : Tutorial.guides
            for guide in guides {
                let file = shelf.appendingPathComponent(guide.file)
                try guide.markdown.write(to: file, atomically: true, encoding: .utf8)
                try setAppearance(of: file, emoji: guide.emoji, color: guide.color)
                try place(file, in: shelf) // 记下顺序
            }
        } catch {
            // 建不了也没关系，用户还是可以自己建
        }
    }
}
