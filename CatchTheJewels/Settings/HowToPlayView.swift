import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                InfoCard(title: "Move Your Crown", systemImage: "hand.draw.fill") {
                    Text("Touch and drag anywhere on the screen to slide your crown left and right. You can adjust sensitivity, or turn on Tilt to Move, in Profile or Settings.")
                }

                InfoCard(title: "Catch Jewels", systemImage: "diamond.fill") {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(JewelKind.allCases) { kind in
                            JewelValueRow(kind: kind)
                        }
                    }
                }

                InfoCard(title: "Avoid Bombs", systemImage: "exclamationmark.triangle.fill") {
                    HStack(spacing: Theme.Spacing.sm) {
                        ArtworkView(kind: .bomb, height: 44)
                        Text("Bombs are dark spheres marked with a yellow X. Catching one costs a life and resets your combo. You start each run with three lives.")
                    }
                }

                InfoCard(title: "Royal Hearts", systemImage: "heart.fill") {
                    HStack(spacing: Theme.Spacing.sm) {
                        ArtworkView(kind: .heart, height: 44)
                        Text("Rare hearts marked with a plus restore a lost life. At full health they're worth 100 bonus points.")
                    }
                }

                InfoCard(title: "Combos", systemImage: "link") {
                    Text("Every 10 jewels caught in a row raises your multiplier, up to ×4. Missing a jewel or catching a bomb resets it. Missed jewels never cost a life.")
                }

                InfoCard(title: "Rising Difficulty", systemImage: "speedometer") {
                    Text("The longer you survive, the faster jewels fall and the more varied the patterns become.")
                }

                InfoCard(title: "Game Modes", systemImage: "gamecontroller.fill") {
                    Text("Classic Mode lasts until your three lives run out. Time Challenge gives you \(Int(GameMode.timeChallengeDuration)) seconds to score as much as you can.")
                }

                InfoCard(title: "Daily Challenge", systemImage: "calendar") {
                    Text("A new 60-second challenge every day, based on your device's date. Everyone gets the same jewels on the same day, and it works offline.")
                }
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(Theme.Spacing.md)
            .readableWidth()
        }
        .background(RoyalBackground())
        .navigationTitle("How to Play")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if isPresented {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("howToPlay.done")
                }
            }
        }
        .accessibilityIdentifier("screen.howToPlay")
    }
}

struct InfoCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label(title, systemImage: systemImage)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.goldLight)
                .accessibilityAddTraits(.isHeader)
            content
                .fixedSize(horizontal: false, vertical: true)
        }
        .royalCard()
    }
}
