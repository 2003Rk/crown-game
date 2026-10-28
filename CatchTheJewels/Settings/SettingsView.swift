import SwiftUI

/// Settings presented as a sheet from the Home gear button.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                PreferencesSections()
                    .padding(Theme.Spacing.md)
                    .readableWidth()
            }
            .scrollIndicators(.hidden)
            .background(RoyalBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        .tint(Theme.Colors.gold)
        .accessibilityIdentifier("screen.settings")
    }

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// Every player preference plus help, privacy, reset and version. Shared by the
/// Settings sheet and the Profile tab so there is one implementation. Must be
/// placed inside a `NavigationStack`.
struct PreferencesSections: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progress
    @State private var confirmResetTutorial = false
    @State private var confirmResetProgress = false

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: Theme.Spacing.lg) {
            SettingsSection(title: "Sound") {
                Toggle(isOn: $settings.musicEnabled) { Label("Music", systemImage: "music.note") }
                    .accessibilityIdentifier("settings.music")
                Toggle(isOn: $settings.soundEffectsEnabled) { Label("Sound Effects", systemImage: "speaker.wave.2.fill") }
                    .accessibilityIdentifier("settings.sound")
                Text("Sounds follow your device's Ring/Silent switch.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            SettingsSection(title: "Feedback") {
                Toggle(isOn: $settings.hapticsEnabled) { Label("Haptics", systemImage: "iphone.radiowaves.left.and.right") }
                    .accessibilityIdentifier("settings.haptics")
            }

            SettingsSection(title: "Controls") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Label("Sensitivity", systemImage: "hand.draw.fill")
                        Spacer()
                        Text(settings.effectiveSensitivity, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.goldLight)
                        Text("×").foregroundStyle(Theme.Colors.goldLight)
                    }
                    Slider(value: $settings.controlSensitivity, in: SettingsStore.sensitivityRange, step: 0.1) {
                        Text("Control sensitivity")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise.fill").accessibilityLabel("Slower")
                    } maximumValueLabel: {
                        Image(systemName: "hare.fill").accessibilityLabel("Faster")
                    }
                    .accessibilityValue("\(settings.effectiveSensitivity, specifier: "%.1f") times")
                    .accessibilityIdentifier("settings.sensitivity")
                }
                if TiltInput.isSupported {
                    Toggle(isOn: $settings.tiltControlsEnabled) { Label("Tilt to Move", systemImage: "gyroscope") }
                        .accessibilityHint("Tilt your device to move the crown. Dragging still works.")
                        .accessibilityIdentifier("settings.tilt")
                }
            }

            SettingsSection(title: "Accessibility") {
                Toggle(isOn: $settings.reduceMotion) { Label("Reduce Motion", systemImage: "figure.walk.motion") }
                    .accessibilityHint("Turns off screen shake and decorative animation.")
                    .accessibilityIdentifier("settings.reduceMotion")
                Toggle(isOn: $settings.largerCatcher) { Label("Larger Crown", systemImage: "arrow.left.and.right.square") }
                    .accessibilityHint("Makes the crown wider so jewels are easier to catch.")
                    .accessibilityIdentifier("settings.largerCatcher")
            }

            SettingsSection(title: "Help") {
                NavigationLink {
                    HowToPlayView()
                } label: {
                    SettingsRowLabel(title: "How to Play", systemImage: "questionmark.circle.fill")
                }
                .accessibilityIdentifier("settings.howToPlay")
                Button {
                    confirmResetTutorial = true
                } label: {
                    SettingsRowLabel(title: "Replay Tutorial", systemImage: "arrow.counterclockwise.circle.fill", showsChevron: false)
                }
                .accessibilityIdentifier("settings.resetTutorial")
            }

            SettingsSection(title: "Privacy & Data") {
                NavigationLink {
                    PrivacyView()
                } label: {
                    SettingsRowLabel(title: "Privacy", systemImage: "hand.raised.fill")
                }
                .accessibilityIdentifier("settings.privacy")
                Button(role: .destructive) {
                    confirmResetProgress = true
                } label: {
                    SettingsRowLabel(title: "Reset Game Progress", systemImage: "trash.fill", showsChevron: false, destructive: true)
                }
                .accessibilityIdentifier("settings.resetProgress")
            }

            SettingsSection(title: "About") {
                SettingsValueRow(title: "Version", systemImage: "info.circle.fill",
                                 value: SettingsView.versionString, identifier: "settings.version")
            }
        }
        .onChange(of: settings.musicEnabled) { _, _ in model.audio.refreshMusic() }
        .confirmationDialog("Replay the tutorial?", isPresented: $confirmResetTutorial, titleVisibility: .visible) {
            Button("Replay Tutorial") {
                model.isSettingsPresented = false
                settings.resetTutorial()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The three introduction screens will be shown again. Your progress is kept.")
        }
        .confirmationDialog("Reset game progress?", isPresented: $confirmResetProgress, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive) {
                model.abandonSuspendedGame()
                progress.resetAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently erases your best scores, statistics, achievements and daily challenge records from this device. Your nickname, avatar and settings are kept.")
        }
    }
}
