import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                InfoCard(title: "Your Game Data", systemImage: "hand.raised.fill") {
                    Text("Catch the Jewels does not require an account. Review the published privacy policy for details about app operation and attribution services included in this version.")
                }
                InfoCard(title: "Stored on This Device", systemImage: "internaldrive.fill") {
                    Text("Your nickname, avatar, scores, statistics, achievements, daily challenge results and settings are saved only on this device. Deleting the app removes them. You can erase your game progress any time with Reset Game Progress in Profile or Settings.")
                }
                InfoCard(title: "Offline Gameplay", systemImage: "wifi.slash") {
                    Text("Core gameplay works without an internet connection. The daily challenge is generated from your device's date.")
                }
                InfoCard(title: "No Permissions Needed", systemImage: "checkmark.shield.fill") {
                    Text("The game doesn't ask for your location, contacts, camera, microphone or photos. The optional Tilt to Move control reads the device's orientation sensor only while you play; nothing is recorded or sent.")
                }
                InfoCard(title: "Just for Fun", systemImage: "sparkles") {
                    Text("Points, jewels and achievements are fictional and have no monetary value. There are no purchases, prizes or real-money rewards.")
                }
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(Theme.Spacing.md)
            .readableWidth()
        }
        .background(RoyalBackground())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("screen.privacy")
    }
}
