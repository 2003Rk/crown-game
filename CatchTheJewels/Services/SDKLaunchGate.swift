import Foundation

@MainActor
final class SDKLaunchGate {
    private static let allowedNotification = Notification.Name("network_allowed")
    private static let deniedNotification = Notification.Name("network_denied")

    private let notificationCenter: NotificationCenter
    private var observerTokens: [NSObjectProtocol] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isReady = false
    private var resultDelayTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        observerTokens = [Self.allowedNotification, Self.deniedNotification].map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.networkAuthorizationResolved()
                }
            }
        }
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.complete()
        }
    }

    func waitUntilReady() async {
        guard !isReady else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func networkAuthorizationResolved() {
        guard !isReady, resultDelayTask == nil else { return }
        resultDelayTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.complete()
        }
    }

    private func complete() {
        guard !isReady else { return }
        isReady = true
        timeoutTask?.cancel()
        resultDelayTask?.cancel()
        observerTokens.forEach(notificationCenter.removeObserver)
        observerTokens.removeAll()
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
