// 界面语言：中文 / English。
// 写界面文字时用 L("中文", "English")，两种语言写在一起，按设置显示。
// 拾记自己的界面切换后立刻生效；菜单栏里系统自带的项目（拷贝、粘贴、窗口…）重新打开拾记后生效。
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh, en
    var id: String { rawValue }
    var displayName: String { self == .zh ? "中文" : "English" }
    /// 告诉 macOS 用哪种语言显示系统自带的文字
    var systemCode: String { self == .zh ? "zh-Hans" : "en" }
}

@Observable
final class Lang {
    static let shared = Lang()
    private static let key = "appLanguage"

    var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.key)
            Self.applyToSystem(current)
            // 已打开的笔记编辑器也换语言
            NotificationCenter.default.post(name: .piknoteLanguageChanged, object: nil)
        }
    }

    var isEnglish: Bool { current == .en }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.key).flatMap(AppLanguage.init(rawValue:)) {
            current = saved
        } else {
            // 第一次打开：默认中文，可以在设置里换成英文
            current = .zh
        }
        Self.applyToSystem(current)
    }

    /// 下次打开时，系统自带的菜单项也用这种语言
    private static func applyToSystem(_ language: AppLanguage) {
        UserDefaults.standard.set([language.systemCode], forKey: "AppleLanguages")
    }

    /// 重新打开拾记（让系统自带的菜单项也换语言）
    func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

/// 界面文字：同时写中文和英文，按设置显示
func L(_ zh: String, _ en: String) -> String {
    Lang.shared.isEnglish ? en : zh
}

extension Notification.Name {
    static let piknoteLanguageChanged = Notification.Name("piknoteLanguageChanged")
}

/// 设置窗口（菜单栏 拾记 → 设置…，⌘,）：通用、外观两页
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label(L("通用", "General"), systemImage: "gearshape") }
            AppearanceSettingsView()
                .tabItem { Label(L("外观", "Appearance"), systemImage: "paintpalette") }
            PersonalizationSettingsView()
                .tabItem { Label(L("个性化", "Personalize"), systemImage: "paintbrush") }
        }
        .frame(width: 560)
    }
}

/// “通用”页：界面语言
struct GeneralSettingsView: View {
    @State private var lang = Lang.shared
    @State private var changedThisSession = false

    var body: some View {
        Form {
            Picker(L("语言", "Language"), selection: $lang.current) {
                ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .onChange(of: lang.current) { changedThisSession = true }

            if changedThisSession {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("菜单栏里系统自带的项目（比如“编辑”菜单里的拷贝、粘贴）要重新打开拾记才会换语言。",
                           "Built-in menu items (like Copy and Paste in the Edit menu) switch language after PikNote restarts."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L("立即重新打开", "Restart Now")) { lang.relaunch() }
                }
                .padding(.top, 6)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
