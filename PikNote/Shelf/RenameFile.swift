// 重命名文件的小窗口：书架图标、书架管理、笔记窗口都用这一个。
// 只改名字，扩展名（.md / .pdf …）不变；表情、底色、在这层里的位置都保留。
import SwiftUI

extension View {
    /// isPresented 变成 true 时弹出重命名小窗；改好后 onRenamed 拿到新位置
    func renameFileAlert(_ url: URL, isPresented: Binding<Bool>, onRenamed: @escaping (URL) -> Void = { _ in }) -> some View {
        modifier(RenameFileAlert(url: url, isPresented: isPresented, onRenamed: onRenamed))
    }
}

private struct RenameFileAlert: ViewModifier {
    let url: URL
    @Binding var isPresented: Bool
    let onRenamed: (URL) -> Void
    @Environment(Library.self) private var library
    @State private var name = ""
    @State private var errorMessage: String?

    private var ext: String { url.pathExtension }

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, shown in
                if shown { name = url.deletingPathExtension().lastPathComponent }
            }
            .alert(L("重命名", "Rename"), isPresented: $isPresented) {
                TextField(L("名字", "Name"), text: $name)
                Button(L("重命名", "Rename")) { commit() }
                Button(L("取消", "Cancel"), role: .cancel) {}
            } message: {
                Text(ext.isEmpty ? L("给“\(url.lastPathComponent)”起个新名字", "Enter a new name for “\(url.lastPathComponent)”")
                     : L("扩展名 .\(ext) 不变。其他笔记里指向它的链接需要自己改。", "The .\(ext) extension stays. Links to it from other notes won’t update."))
            }
            .alert(L("没能重命名", "Couldn’t Rename"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button(L("好", "OK")) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
    }

    private func commit() {
        do {
            let renamed = try library.renameFile(url, to: name)
            if renamed != url.standardizedFileURL { onRenamed(renamed) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
