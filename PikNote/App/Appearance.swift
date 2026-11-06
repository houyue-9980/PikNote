// 外观：浅色（默认，白底）、深色、护眼（暖色纸感）；可选“跟随系统自动切换浅色 / 深色”。
// 主题同时作用于书架、编辑页面和公式快捷栏。
import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case light, dark, sepia
    var id: String { rawValue }

    var name: String {
        switch self {
        case .light: L("浅色", "Light")
        case .dark: L("深色", "Dark")
        case .sepia: L("护眼", "Sepia")
        }
    }

    var caption: String {
        switch self {
        case .light: L("干净的白底", "Clean white page")
        case .dark: L("夜里写字不刺眼", "Easy on the eyes at night")
        case .sepia: L("暖色纸感，长时间阅读", "Warm paper for long reading")
        }
    }

    /// 页面底色（书架、编辑区）
    var pageColor: Color {
        switch self {
        case .light: Color(nsColor: .textBackgroundColor)
        case .dark: Color(nsColor: .textBackgroundColor)
        case .sepia: Color(red: 0.973, green: 0.945, blue: 0.890)
        }
    }
}

@Observable
final class AppearanceSettings {
    static let shared = AppearanceSettings()

    var theme: Theme { didSet { save(); apply() } }
    var followSystem: Bool { didSet { save(); apply() } }

    private init() {
        theme = UserDefaults.standard.string(forKey: "theme").flatMap(Theme.init(rawValue:)) ?? .light
        followSystem = UserDefaults.standard.bool(forKey: "themeFollowsSystem")
    }

    private func save() {
        UserDefaults.standard.set(theme.rawValue, forKey: "theme")
        UserDefaults.standard.set(followSystem, forKey: "themeFollowsSystem")
    }

    /// 让窗口、工具栏、侧栏这些系统部分也跟着变深 / 变浅
    func apply() {
        NSApplication.shared.appearance = followSystem ? nil
            : NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
    }

    /// 实际生效的主题：跟随系统时看系统现在是浅色还是深色
    func effective(_ scheme: ColorScheme) -> Theme {
        followSystem ? (scheme == .dark ? .dark : .light) : theme
    }
}

extension View {
    /// 页面底色跟着主题走
    func pikPageBackground() -> some View { modifier(PageBackground()) }
}

private struct PageBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        // 底色：个性化里设置的（没设置就是主题默认的）
        let theme = AppearanceSettings.shared.effective(scheme)
        let color = Personalization.shared.backgroundColor(theme: theme)
        // 换主题、换底色时，颜色渐变过去
        content.background { color.pikAnimation(Motion.standard, value: color.description) }
    }
}

/// 设置窗口里的“外观”页（照设计稿：三张主题卡片 + 跟随系统）
struct AppearanceSettingsView: View {
    @State private var settings = AppearanceSettings.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L("主题会同时应用到书架、编辑页面和公式快捷栏", "The theme applies to the bookshelf, the editor, and the formula bar."))
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                ForEach(Theme.allCases) { theme in
                    ThemeCard(theme: theme,
                              selected: settings.effective(scheme) == theme,
                              dimmed: settings.followSystem && theme == .sepia) {
                        settings.theme = theme
                        settings.followSystem = false // 手动选了一个，就不再跟随系统
                    }
                }
            }
            Toggle(L("跟随系统自动切换浅色 / 深色", "Match the system (light / dark)"), isOn: $settings.followSystem)
        }
        .padding(24)
    }
}

private struct ThemeCard: View {
    let theme: Theme
    let selected: Bool
    let dimmed: Bool
    let action: () -> Void

    // 小窗口示意图的配色
    private var colors: (window: Color, sidebar: Color, bar: Color, title: Color, line: Color) {
        switch theme {
        case .light: (.white, Color(white: 0.96), Color(white: 0.96), Color(white: 0.15), Color(white: 0.85))
        case .dark: (Color(white: 0.13), Color(white: 0.18), Color(white: 0.18), Color(white: 0.92), Color(white: 0.35))
        case .sepia: (Color(red: 0.98, green: 0.96, blue: 0.91), Color(red: 0.95, green: 0.92, blue: 0.85),
                      Color(red: 0.95, green: 0.92, blue: 0.85), Color(white: 0.15), Color(red: 0.85, green: 0.80, blue: 0.70))
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                preview
                    .frame(width: 150, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.12)))
                    .padding(3)
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2.5))
                Text(theme.name).font(.headline)
                Text(theme.caption).font(.caption).foregroundStyle(.secondary)
            }
            .opacity(dimmed ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var preview: some View {
        let c = colors
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(Color.red.opacity(0.85)).frame(width: 6, height: 6)
                Circle().fill(Color.yellow.opacity(0.9)).frame(width: 6, height: 6)
                Circle().fill(Color.green.opacity(0.85)).frame(width: 6, height: 6)
                Spacer()
            }
            .padding(.horizontal, 7).frame(height: 14).background(c.bar)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<3) { _ in Capsule().fill(c.line).frame(width: 26, height: 3) }
                    Spacer()
                }
                .padding(7).frame(width: 42).frame(maxHeight: .infinity).background(c.sidebar)
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(c.title).frame(width: 44, height: 5)
                    Capsule().fill(c.line).frame(width: 74, height: 3)
                    Capsule().fill(c.line).frame(width: 66, height: 3)
                    Capsule().fill(c.line).frame(width: 52, height: 3)
                    Spacer()
                }
                .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(c.window)
            }
        }
    }
}
