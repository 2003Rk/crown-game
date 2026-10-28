import SwiftUI

@main
struct CatchTheJewelsApp: App {
    @State private var model: AppModel
    private let sdkLaunchGate: SDKLaunchGate

    init() {
        sdkLaunchGate = SDKLaunchGate()
        let options = LaunchOptions.current()
        let defaults = UserDefaults.standard
        if options.resetState, let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        _model = State(initialValue: AppModel(store: defaults, launchOptions: options))
    }

    var body: some Scene {
        WindowGroup {
            RootView(sdkLaunchGate: sdkLaunchGate)
                .environment(model)
                .environment(model.settings)
                .environment(model.progress)
                .environment(model.profile)
        }
    }
}
