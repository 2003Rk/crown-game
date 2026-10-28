import Foundation

/// Launch arguments used by UI tests and screenshot capture.
///
/// Parsed only in DEBUG builds; Release builds always use the defaults, so no test
/// hooks are reachable in the App Store binary.
struct LaunchOptions {
    var resetState = false
    var skipOnboarding = false
    var skipSplash = false
    var scenario: GameScenario = .standard
    var initialTab: AppTab?
    var autoStartClassic = false

    static func current() -> LaunchOptions {
        #if DEBUG
        return parse(ProcessInfo.processInfo.arguments)
        #else
        return LaunchOptions()
        #endif
    }

    static func parse(_ arguments: [String]) -> LaunchOptions {
        var options = LaunchOptions()
        options.resetState = arguments.contains("-resetState")
        options.skipOnboarding = arguments.contains("-skipOnboarding")
        options.skipSplash = arguments.contains("-skipSplash")
        options.autoStartClassic = arguments.contains("-autoStartClassic")
        if let index = arguments.firstIndex(of: "-scenario"), index + 1 < arguments.count {
            options.scenario = GameScenario(rawValue: arguments[index + 1]) ?? .standard
        }
        if let index = arguments.firstIndex(of: "-initialTab"), index + 1 < arguments.count {
            options.initialTab = AppTab(rawValue: arguments[index + 1])
        }
        return options
    }
}
