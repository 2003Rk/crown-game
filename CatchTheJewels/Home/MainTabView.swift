import SwiftUI

/// The four-tab shell. Each tab's view is created on first visit and then kept
/// alive, so scroll positions, navigation stacks and edits survive tab switches.
struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var visitedTabs: Set<AppTab> = []

    var body: some View {
        @Bindable var model = model
        ZStack {
            ForEach(AppTab.allCases) { tab in
                if visitedTabs.contains(tab) || model.selectedTab == tab {
                    let isSelected = model.selectedTab == tab
                    screen(for: tab)
                        .opacity(isSelected ? 1 : 0)
                        .allowsHitTesting(isSelected)
                        .accessibilityHidden(!isSelected)
                        .zIndex(isSelected ? 1 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RoyalTabBar(selection: model.selectedTab) { model.select($0) }
        }
        .onAppear { visitedTabs.insert(model.selectedTab) }
        .onChange(of: model.selectedTab) { _, tab in visitedTabs.insert(tab) }
        .sheet(isPresented: $model.isSettingsPresented) {
            SettingsView()
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $model.isGamePresented, onDismiss: model.gameCoverDismissed) {
            if let game = model.game {
                GameView(controller: game, onExit: model.exitGame)
                    .environment(\.prefersReducedMotion, model.settings.reduceMotion || UIAccessibility.isReduceMotionEnabled)
            }
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .play: PlayView()
        case .achievements: AchievementsView()
        case .profile: ProfileView()
        }
    }
}
