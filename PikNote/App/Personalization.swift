// 个性化：标题 1–5 的颜色，浅色 / 深色 / 护眼三种主题各存一套。
// （页面底色以前也能改，2.0.3 起去掉了：底色固定用每个主题自己的颜色）
// 每套都有好认的默认颜色；用户改过的记住，切换主题再切回来还在。
// 只影响拾记里显示的样子，不写进笔记文件（文件还是普通的 .md）。
import SwiftUI

@Observable
final class Personalization {
    static let shared = Personalization()
    private static let key = "headingColorsByTheme"

    /// 0 号是页面底色（固定用主题的颜色，不能改），1–5 是标题
    static let background = 0

    /// 默认颜色：每种主题一套，和背景搭配，标题之间也分得清
    static let defaults: [Theme: [Int: String]] = [
        .light: [0: "#FFFFFF", 1: "#C2410C", 2: "#1D4ED8", 3: "#047857", 4: "#7C3AED", 5: "#64748B"],
        .dark:  [0: "#1E1E1E", 1: "#FB923C", 2: "#60A5FA", 3: "#34D399", 4: "#A78BFA", 5: "#94A3B8"],
        .sepia: [0: "#F8F1E3", 1: "#A0461C", 2: "#2F5C8F", 3: "#4F7A3A", 4: "#7A4E8C", 5: "#7A6C5B"],
    ]

    /// 用户改过的颜色：主题 → 标题级别 → #RRGGBB（没改过的用默认）
    private(set) var custom: [Theme: [Int: String]] = [:]

    // ---------- 字体和行间距（所有主题共用） ----------

    /// 正文字体（字体家族名，比如 "Songti SC"）；nil = 系统默认（苹方 / San Francisco）
    var fontFamily: String? {
        didSet { UserDefaults.standard.set(fontFamily, forKey: "fontFamily"); notify() }
    }
    /// 行间距（行高是字号的几倍）
    var lineHeight: Double {
        didSet { UserDefaults.standard.set(lineHeight, forKey: "lineHeight"); notify() }
    }
    static let defaultLineHeight = 1.7
    static let lineHeightRange = 1.3...2.4

    /// 段间距（段落之间额外空多少，字号的几倍）
    var paragraphSpacing: Double {
        didSet { UserDefaults.standard.set(paragraphSpacing, forKey: "paragraphSpacing"); notify() }
    }
    static let defaultParagraphSpacing = 0.3
    static let paragraphSpacingRange = 0.0...1.5

    /// 推荐的中文字体（只显示这台电脑上装了的）
    static let recommendedFonts: [(family: String, zh: String, en: String)] = [
        ("Songti SC", "宋体", "Songti"),
        ("Kaiti SC", "楷体", "Kaiti"),
        ("Yuanti SC", "圆体", "Yuanti"),
        ("Lantinghei SC", "兰亭黑", "Lantinghei"),
        ("Hiragino Sans GB", "冬青黑体", "Hiragino Sans GB"),
        ("HanziPen SC", "手札体", "HanziPen"),
    ]

    private init() {
        fontFamily = UserDefaults.standard.string(forKey: "fontFamily")
        let savedLineHeight = UserDefaults.standard.double(forKey: "lineHeight")
        lineHeight = Self.lineHeightRange.contains(savedLineHeight) ? savedLineHeight : Self.defaultLineHeight
        paragraphSpacing = (UserDefaults.standard.object(forKey: "paragraphSpacing") as? Double)
            .flatMap { Self.paragraphSpacingRange.contains($0) ? $0 : nil } ?? Self.defaultParagraphSpacing
        let saved = UserDefaults.standard.dictionary(forKey: Self.key) as? [String: [String: String]] ?? [:]
        for (themeName, levels) in saved {
            guard let theme = Theme(rawValue: themeName) else { continue }
            custom[theme] = Dictionary(uniqueKeysWithValues: levels.compactMap { k, v in Int(k).map { ($0, v) } })
        }
        // 2.0.3 起页面底色不能改了：以前改过的底色丢掉，回到主题自己的颜色
        var droppedBackground = false
        for theme in Array(custom.keys) where custom[theme]?[Self.background] != nil {
            custom[theme]?[Self.background] = nil
            if custom[theme]?.isEmpty == true { custom[theme] = nil }
            droppedBackground = true
        }
        // 早一版只存了一套颜色，搬到“浅色”里
        if let old = UserDefaults.standard.dictionary(forKey: "headingColors") as? [String: String] {
            if custom[.light] == nil {
                custom[.light] = Dictionary(uniqueKeysWithValues: old.compactMap { k, v in Int(k).map { ($0, v) } })
            }
            UserDefaults.standard.removeObject(forKey: "headingColors")
            // 注意：这里还在初始化，不能发“颜色变了”的通知——
            // 收到通知的编辑器会回头来读 Personalization.shared，而它还没初始化完，会卡死自己（崩溃）
            save(notify: false)
        }
        if droppedBackground { save(notify: false) } // 同上：初始化中不发通知
    }

    /// 某个主题下某级标题现在的颜色
    func color(_ level: Int, theme: Theme) -> String {
        custom[theme]?[level] ?? Self.defaults[theme]?[level] ?? "#000000"
    }

    func isCustom(_ level: Int, theme: Theme) -> Bool { custom[theme]?[level] != nil }
    func hasCustom(theme: Theme) -> Bool { !(custom[theme] ?? [:]).isEmpty }

    func setColor(_ hex: String?, level: Int, theme: Theme) {
        guard level != Self.background else { return } // 底色不能改
        var levels = custom[theme] ?? [:]
        // 选回和默认一样的颜色，就当作没改
        levels[level] = (hex == Self.defaults[theme]?[level]) ? nil : hex
        custom[theme] = levels.isEmpty ? nil : levels
        save()
    }

    func reset(theme: Theme) {
        custom[theme] = nil
        save()
    }

    private func save(notify: Bool = true) {
        let stored = Dictionary(uniqueKeysWithValues: custom.map { theme, levels in
            (theme.rawValue, Dictionary(uniqueKeysWithValues: levels.map { (String($0.key), $0.value) }))
        })
        UserDefaults.standard.set(stored, forKey: Self.key)
        // 已打开的笔记马上换颜色
        if notify { self.notify() }
    }

    /// 告诉已打开的笔记：样子变了（颜色、字体、行间距）
    private func notify() {
        NotificationCenter.default.post(name: .piknoteHeadingColorsChanged, object: nil)
    }

    /// 交给编辑器的字体和行间距
    var typographyForEditor: [String: Any] {
        ["font": fontFamily ?? "", "lineHeight": Self.effectiveLineHeight(family: fontFamily, setting: lineHeight),
         "paragraphSpacing": paragraphSpacing]
    }

    /// 编辑器里实际用的行高（字号的几倍），和设置页的预览算法一致：
    /// 字体本身的行高 + 额外间距（设置值 - 1.2）。
    /// 中文字体本身的行高比较高（苹方约 1.43 倍），所以要按字体算，正文和预览才会一样。
    static func effectiveLineHeight(family: String?, setting: Double) -> Double {
        naturalLineHeight(family: family) + (setting - 1.2)
    }

    /// 字体本身的行高（字号的几倍）。中文会用到苹方：字体里没有中文时，按苹方和它里面较高的算
    static func naturalLineHeight(family: String?) -> Double {
        let size: CGFloat = 14
        let layout = NSLayoutManager()
        func ratio(_ font: NSFont) -> Double { Double(layout.defaultLineHeight(for: font) / size) }
        let pingFang = NSFontManager.shared.font(withFamily: "PingFang SC", traits: [], weight: 5, size: size)
        let chinese = pingFang.map(ratio) ?? 1.43
        guard let family, let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) else {
            return chinese // 系统默认：中文用苹方
        }
        let hasChinese = font.coveredCharacterSet.contains(Unicode.Scalar("中"))
        return hasChinese ? ratio(font) : max(ratio(font), chinese)
    }

    /// 交给编辑器：这个主题下的底色（"0"）和 1–5 级标题颜色，["0": "#FFFFFF", "1": "#C2410C", …]
    func forEditor(theme: Theme) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (0...5).map { (String($0), color($0, theme: theme)) })
    }

    /// 这个主题的页面底色
    func backgroundColor(theme: Theme) -> Color {
        Color(hex: color(Self.background, theme: theme)) ?? .white
    }
}

extension Notification.Name {
    static let piknoteHeadingColorsChanged = Notification.Name("piknoteHeadingColorsChanged")
}

extension Color {
    /// 颜色 → #RRGGBB
    var hexString: String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X", Int(round(c.redComponent * 255)), Int(round(c.greenComponent * 255)), Int(round(c.blueComponent * 255)))
    }

    /// #RRGGBB → 颜色
    init?(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

/// 设置窗口里的“个性化”页
struct PersonalizationSettingsView: View {
    @State private var settings = Personalization.shared
    @Environment(\.colorScheme) private var scheme
    /// 正在调哪个主题的颜色（打开时默认是现在用着的主题）
    @State private var theme: Theme?

    private let sizes: [Int: CGFloat] = [1: 22, 2: 18, 3: 15, 4: 14, 5: 13]
    private var editing: Theme { theme ?? AppearanceSettings.shared.effective(scheme) }

    // 预览区用这个主题的底色和文字颜色，调的时候就能看出清不清楚
    private var previewBackground: Color { settings.backgroundColor(theme: editing) }
    private var previewText: Color {
        switch editing {
        case .light: Color(white: 0.11)
        case .dark: Color(white: 0.9)
        case .sepia: Color(red: 0.23, green: 0.19, blue: 0.15)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("标题颜色只改变拾记里显示的样子，不会写进笔记文件。浅色、深色、护眼各存一套。",
                   "Heading colors only change how notes look in PikNote and aren’t saved into your files. Light, Dark, and Sepia each keep their own set."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("", selection: Binding(get: { editing }, set: { theme = $0 })) {
                ForEach(Theme.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 300)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                ForEach(1...5, id: \.self) { level in
                    GridRow {
                        Text(L("标题 \(level)", "Heading \(level)"))
                            .font(.system(size: sizes[level] ?? 13, weight: .bold))
                            .foregroundStyle(Color(hex: settings.color(level, theme: editing)) ?? previewText)
                            .frame(width: 150, alignment: .leading)
                        ColorPicker("", selection: binding(for: level), supportsOpacity: false)
                            .labelsHidden()
                        Button(L("默认", "Default")) { settings.setColor(nil, level: level, theme: editing) }
                            .disabled(!settings.isCustom(level, theme: editing))
                    }
                }
                GridRow {
                    Text(L("正文文字是这样的", "Body text looks like this"))
                        .font(.system(size: 13))
                        .foregroundStyle(previewText)
                        .gridCellColumns(3)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(previewBackground))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.1)))
            .environment(\.colorScheme, editing == .dark ? .dark : .light) // 取色器按钮也跟着预览区的深浅

            HStack {
                Spacer()
                Button(L("这套颜色恢复默认", "Reset Colors for This Theme")) { settings.reset(theme: editing) }
                    .disabled(!settings.hasCustom(theme: editing))
            }

            Divider()
            TypographySettings(settings: settings, background: previewBackground, text: previewText, dark: editing == .dark)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func binding(for level: Int) -> Binding<Color> {
        Binding(
            get: { Color(hex: settings.color(level, theme: editing)) ?? .primary },
            set: { settings.setColor($0.hexString, level: level, theme: editing) }
        )
    }
}

/// 字体和行间距（所有主题共用）
private struct TypographySettings: View {
    @Bindable var settings: Personalization
    let background: Color
    let text: Color
    let dark: Bool

    private let installed = Set(NSFontManager.shared.availableFontFamilies)
    /// 左边标签的宽度：英文“Paragraph spacing”比较长
    private var labelWidth: CGFloat { Lang.shared.isEnglish ? 130 : 60 }
    private var recommended: [(family: String, zh: String, en: String)] {
        Personalization.recommendedFonts.filter { installed.contains($0.family) }
    }
    private var allFamilies: [String] { NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") } }

    private let previewSize: CGFloat = 14
    /// 预览用两段：既看得出行间距，也看得出段间距
    private var previewParagraphs: [String] {
        [L("拾记 PikNote 是一个超轻量的 Mac 原生笔记软件：书架是唯一的导航，每篇笔记都是一个普通的 .md 文件，写的时候所见即所得，写数学公式不用背 LaTeX。",
           "PikNote is a lightweight, native Mac note app. The bookshelf is your only navigation, every note is a plain .md file, what you see is what you get, and you can write math without memorizing LaTeX."),
         L("文件永远是你的，卸掉软件后笔记一切如常。",
           "Your files are always yours, even if you uninstall the app.")]
    }

    private var fontName: String {
        guard let family = settings.fontFamily else { return L("系统默认（苹方）", "System Default") }
        if let r = recommended.first(where: { $0.family == family }) { return L(r.zh, r.en) }
        return family
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("字体和行间距对三种主题都生效。", "Font and line spacing apply to all themes."))
                .font(.callout).foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text(L("字体", "Font")).frame(width: labelWidth, alignment: .leading)
                Menu(fontName) {
                    Button(L("系统默认（苹方）", "System Default")) { settings.fontFamily = nil }
                    Divider()
                    ForEach(recommended, id: \.family) { r in
                        Button(L(r.zh, r.en)) { settings.fontFamily = r.family }
                    }
                    Divider()
                    Menu(L("全部字体", "All Fonts")) {
                        ForEach(allFamilies, id: \.self) { family in
                            Button(family) { settings.fontFamily = family }
                        }
                    }
                }
                .fixedSize()
            }

            HStack(spacing: 12) {
                Text(L("行间距", "Line spacing")).frame(width: labelWidth, alignment: .leading)
                Text(L("紧", "Tight")).font(.caption).foregroundStyle(.secondary)
                Slider(value: $settings.lineHeight, in: Personalization.lineHeightRange, step: 0.1)
                    .frame(maxWidth: 220)
                Text(L("松", "Loose")).font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f", settings.lineHeight)).monospacedDigit().frame(width: 30)
                Button(L("默认", "Default")) { settings.lineHeight = Personalization.defaultLineHeight }
                    .disabled(abs(settings.lineHeight - Personalization.defaultLineHeight) < 0.05)
            }

            HStack(spacing: 12) {
                Text(L("段间距", "Paragraph spacing")).frame(width: labelWidth, alignment: .leading)
                Text(L("紧", "Tight")).font(.caption).foregroundStyle(.secondary)
                Slider(value: $settings.paragraphSpacing, in: Personalization.paragraphSpacingRange, step: 0.1)
                    .frame(maxWidth: 220)
                Text(L("松", "Loose")).font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f", settings.paragraphSpacing)).monospacedDigit().frame(width: 30)
                Button(L("默认", "Default")) { settings.paragraphSpacing = Personalization.defaultParagraphSpacing }
                    .disabled(abs(settings.paragraphSpacing - Personalization.defaultParagraphSpacing) < 0.05)
            }

            // 示例文字：用选的字体和行间距显示
            Text(L("预览", "Preview")).font(.caption).foregroundStyle(.secondary)
            // 段与段之间：段间距 + 一份额外行距（网页里每段上下各带半份行距，加起来正好一份），这样和编辑器完全一致
            VStack(alignment: .leading, spacing: CGFloat(settings.paragraphSpacing + settings.lineHeight - 1.2) * previewSize) {
                ForEach(previewParagraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(settings.fontFamily.map { Font.custom($0, size: previewSize) } ?? .system(size: previewSize))
                        .lineSpacing(CGFloat(settings.lineHeight - 1.2) * previewSize) // 和编辑器同一个算法：字体本身行高 + 额外间距
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true) // 自动换行，不截成一行
                }
            }
                .foregroundStyle(text)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(background))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.1)))
        }
    }
}
