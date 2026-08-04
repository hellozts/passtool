import Foundation
#if os(macOS)
import AppKit
#endif

/// 无操作超时监控：达到设定时长后触发回调（用于自动锁定）。
@MainActor
final class IdleMonitor: ObservableObject {
    static let shared = IdleMonitor()

    private var timer: Timer?
    private var lastActivity: Date = Date()
    var onIdle: (() -> Void)?

    func start() {
        lastActivity = Date()
        timer?.invalidate()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        #if os(macOS)
        installMacMonitors()
        #endif
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        #if os(macOS)
        removeMacMonitors()
        #endif
    }

    /// 用户有活动时调用，重置计时
    func bump() {
        lastActivity = Date()
    }

    private func check() {
        let timeout = TimeInterval(max(15, AppSettings.shared.idleTimeoutSeconds))
        if Date().timeIntervalSince(lastActivity) >= timeout {
            onIdle?()
            lastActivity = Date() // 避免重复触发
        }
    }

    // MARK: - macOS 事件监听

    #if os(macOS)
    private var localMonitor: Any?

    // 仅监听本应用内的事件。不使用全局监听，否则用户切换到其他 App 时
    // 全局事件会持续 bump，导致无法因"未活动"而自动锁定。
    private func installMacMonitors() {
        removeMacMonitors()
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .keyDown, .scrollWheel,
                                           .leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.bump() }
            return event
        }
    }

    private func removeMacMonitors() {
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
    }
    #endif
}
