import SpriteKit
import SwiftUI

/// How the player left the game screen.
enum GameExit {
    /// Back to Home with the run paused; it can be resumed later from Home or Play.
    case suspend
    /// The run is over (or abandoned) and should be discarded.
    case finish
}

/// Full-screen gameplay: the SpriteKit playfield with SwiftUI HUD and overlays.
struct GameView: View {
    let controller: GameController
    let onExit: (GameExit) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.prefersReducedMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GameSceneContainer(scene: controller.scene)
                    .ignoresSafeArea()
                    .accessibilityElement()
                    .accessibilityLabel("Playfield")
                    .accessibilityHint("Drag left or right anywhere to move the crown.")
                    .accessibilityAddTraits(.allowsDirectInteraction)
                    .accessibilityIdentifier("game.playfield")

                VStack(spacing: 0) {
                    GameHUD(controller: controller)
                    if let achievement = controller.achievementToast {
                        AchievementToast(achievement: achievement) { controller.dismissAchievementToast() }
                            .padding(.top, Theme.Spacing.sm)
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                            .id(achievement)
                    }
                    if let multiplier = controller.comboBanner {
                        ComboBanner(multiplier: multiplier) { controller.clearComboBanner() }
                            .padding(.top, Theme.Spacing.sm)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: controller.comboBanner)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: controller.achievementToast)

                overlay
            }
            .onAppear {
                controller.scene.updateSafeInsets(UIEdgeInsets(proxy.safeAreaInsets))
            }
            .onChange(of: proxy.safeAreaInsets) { _, insets in
                controller.scene.updateSafeInsets(UIEdgeInsets(insets))
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { _, phase in
            // Never let a run continue in the background or behind system UI.
            if phase != .active { controller.pause() }
        }
        .onDisappear {
            controller.suspend()
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch controller.phase {
        case .countdown:
            CountdownOverlay(number: controller.hud.countdown, mode: controller.mode)
                .allowsHitTesting(false)
        case .playing:
            EmptyView()
        case .paused:
            PauseOverlay(
                controller: controller,
                onResume: { controller.resume() },
                onRestart: { controller.restart() },
                onHome: { onExit(.suspend) }
            )
            .transition(.opacity)
        case .gameOver:
            if let summary = controller.summary {
                GameOverOverlay(
                    summary: summary,
                    onPlayAgain: { controller.restart() },
                    onHome: { onExit(.finish) }
                )
                .transition(.opacity)
            }
        }
    }
}

private extension UIEdgeInsets {
    init(_ insets: EdgeInsets) {
        self.init(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
    }
}

/// Hosts the SpriteKit scene in an `SKView`.
struct GameSceneContainer: UIViewRepresentable {
    let scene: GameScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.isMultipleTouchEnabled = false
        view.allowsTransparency = false
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene {
            view.presentScene(scene)
        }
    }

    static func dismantleUIView(_ view: SKView, coordinator: ()) {
        view.presentScene(nil)
    }
}

// MARK: - HUD

struct GameHUD: View {
    let controller: GameController

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                pauseButton
                score
                timer
                multiplier
                lives
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    pauseButton
                    score
                    Spacer(minLength: 0)
                    timer
                }
                HStack(spacing: Theme.Spacing.sm) {
                    multiplier
                    Spacer(minLength: 0)
                    lives
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .frame(maxWidth: .infinity)
        .glassBackground(Capsule(style: .continuous), emphasis: .subtle)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var pauseButton: some View {
        RoundIconButton(systemImage: "pause.fill", label: "Pause", size: 46) {
            controller.pause()
        }
        .disabled(controller.phase == .gameOver || controller.phase == .paused)
        .accessibilityIdentifier("hud.pause")
    }

    private var score: some View {
        let hud = controller.hud
        return VStack(alignment: .leading, spacing: 0) {
            Text("Score")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(hud.score.formatted())
                .font(Theme.Typography.scoreValue)
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score")
        .accessibilityValue("\(hud.score)")
        .accessibilityIdentifier("hud.score")
    }

    @ViewBuilder
    private var timer: some View {
        if let seconds = controller.hud.secondsRemaining {
            Label("\(seconds)s", systemImage: "timer")
                .font(Theme.Typography.headline.monospacedDigit())
                .foregroundStyle(seconds <= 10 ? Theme.Colors.danger : Theme.Colors.goldLight)
                .accessibilityLabel("Time remaining")
                .accessibilityValue("\(seconds) seconds")
                .accessibilityIdentifier("hud.timer")
        }
    }

    @ViewBuilder
    private var multiplier: some View {
        if controller.hud.multiplier > 1 {
            Text("×\(controller.hud.multiplier)")
                .font(Theme.Typography.headline.monospacedDigit())
                .foregroundStyle(Theme.Colors.textOnGold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.Colors.goldGradient))
                .accessibilityLabel("Combo multiplier times \(controller.hud.multiplier)")
        }
    }

    private var lives: some View {
        LivesView(lives: controller.hud.lives, maxLives: controller.hud.maxLives)
            .accessibilityIdentifier("hud.lives")
    }
}

private struct ComboBanner: View {
    let multiplier: Int
    let onFinished: () -> Void

    var body: some View {
        Text("Combo ×\(multiplier)!")
            .font(Theme.Typography.title2)
            .foregroundStyle(Theme.Colors.textOnGold)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Capsule().fill(Theme.Colors.goldGradient))
            .shadow(color: Theme.Shadow.glow, radius: 10)
            .accessibilityAddTraits(.updatesFrequently)
            .task(id: multiplier) {
                try? await Task.sleep(for: .seconds(1.2))
                onFinished()
            }
    }
}

/// Slides in when an achievement unlocks mid-run.
private struct AchievementToast: View {
    let achievement: Achievement
    let onFinished: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            AchievementBadge(achievement: achievement, unlocked: true, size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("Achievement Unlocked")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.goldLight)
                Text(achievement.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .frame(maxWidth: 360)
        .glassBackground(Capsule(style: .continuous), emphasis: .highlighted)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("game.achievementToast")
        .task(id: achievement) {
            UIAccessibility.post(notification: .announcement, argument: "Achievement unlocked: \(achievement.title)")
            try? await Task.sleep(for: .seconds(2.4))
            onFinished()
        }
    }
}

// MARK: - Countdown

private struct CountdownOverlay: View {
    let number: Int
    let mode: GameMode

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(mode.title)
                .font(Theme.Typography.title2)
                .foregroundStyle(Theme.Colors.goldLight)
            Text(number > 0 ? "\(number)" : "Go!")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.goldGradient)
                .shadow(color: Theme.Shadow.glow, radius: 16)
                .contentTransition(.numericText(countsDown: true))
            if let challenge = mode.dailyChallenge {
                Text(challenge.goalDescription)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            Label("Drag anywhere to move your crown", systemImage: "hand.draw")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.xl)
        .readableWidth()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Get ready. Starting in \(number)")
        .accessibilityIdentifier("game.countdown")
    }
}
