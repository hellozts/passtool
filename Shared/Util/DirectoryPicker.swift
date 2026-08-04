import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
import UniformTypeIdentifiers
#endif

/// 跨平台目录选择器
enum DirectoryPicker {

    /// 当前保存目录的可读描述
    static func currentLocationDescription() -> String {
        VaultStore.resolvedVaultURL().path
    }

    /// 是否使用了自定义目录
    static var hasCustomLocation: Bool {
        AppSettings.shared.vaultBookmark != nil
    }

    /// 重置为默认目录
    static func resetToDefault() {
        VaultStore.clearVaultLocation()
    }

    #if os(macOS)
    /// macOS：弹出 NSOpenPanel 选择目录
    static func pick(onComplete: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择此目录"
        panel.message = "选择密码库的保存目录（将在此目录下创建加密文件）"
        panel.begin { response in
            if response == .OK {
                onComplete(panel.url)
            } else {
                onComplete(nil)
            }
        }
    }
    #endif
}

#if os(iOS)
/// iOS：文件夹选择器（UIViewControllerRepresentable）
struct iOSFolderPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}
#endif
