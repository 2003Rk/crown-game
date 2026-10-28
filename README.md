# Catch the Jewels

A native iOS and iPadOS arcade game. You move a royal crown to catch falling jewels and dodge bombs. It's built with SwiftUI and SpriteKit, supports offline gameplay, needs no account and has no in-app purchases.

## Requirements

- Xcode 16 or later (built and verified with Xcode 26.3, iOS SDK 26.2)
- Deployment target iOS 17.0, for iPhone and iPad
- Apple-silicon Mac for simulator builds (the delivered SDK simulator library is ARM64-only)
- Optional: [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), only needed to regenerate the project from `project.yml`

## Open and run

1. Open `CatchTheJewels.xcodeproj`.
2. Set your signing details (see below).
3. Select the **CatchTheJewels** scheme and an iPhone or iPad simulator or device, then press **Run** (⌘R).

The project file is committed, so XcodeGen is optional. If you add or rename source files, regenerate the project with `xcodegen generate`.

## Bundle identifier, signing team and archiving

All identifiers live in one file: `Config/Base.xcconfig`.

```
APP_BUNDLE_IDENTIFIER = com.yourcompany.catchthejewels   // replace with your registered bundle ID
APP_DEVELOPMENT_TEAM =                                    // your 10-character Team ID
```

1. In the [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list), register an App ID with your bundle identifier. No extra capabilities are needed.
2. Put the bundle ID and your Team ID (from Xcode > Settings > Accounts, or the Membership page) into `Config/Base.xcconfig`.
3. Signing is set to **Automatic**. Xcode creates the provisioning profiles.
4. To archive, select **Any iOS Device (arm64)** and choose **Product > Archive**. The Archive action uses the Release configuration. Then go to **Organizer > Distribute App > App Store Connect**.
5. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` (or in the target's build settings) for each upload.

Test bundle IDs derive automatically from `APP_BUNDLE_IDENTIFIER`.

## Tests

From Xcode: **Product > Test** (⌘U). This runs both unit and UI tests.

From the command line:

```sh
# Unit tests: rules, scoring, difficulty, spawning, persistence, statistics, achievements,
# daily challenge, profile, settings, navigation
xcodebuild test -project CatchTheJewels.xcodeproj -scheme CatchTheJewels \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CatchTheJewelsTests

# UI tests: onboarding, four tabs, Play Now, mode selection, start/pause/resume, game over,
# restart, profile persistence, settings, reset confirmation, backgrounding
xcodebuild test -project CatchTheJewels.xcodeproj -scheme CatchTheJewels \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CatchTheJewelsUITests
```

UI tests use launch arguments that are parsed **only in DEBUG builds** (`LaunchOptions.swift`): `-resetState`, `-skipOnboarding`, `-skipSplash`, `-scenario bombsOnly`, `-initialTab <tab>` and `-autoStartClassic`. Release builds ignore them.

## Project layout

```
CatchTheJewels/
  App/             Entry point, AppModel (navigation and game lifecycle), RootView, splash, Info.plist
  DesignSystem/    Theme tokens (colors, type, spacing) and reusable components and button styles
  Artwork/         ArtworkPainter (Core Graphics drawings of jewels, bomb, heart, crown) and its renderer/cache
  Models/          Pure game logic: GameSession, Difficulty, SpawnPlanner, SeededGenerator, geometry, PlayerProgress
  Game/            SpriteKit GameScene and nodes, GameController, SwiftUI GameView, HUD and overlays
  DesignSystem/    (also) RoyalTabBar — the custom four-tab bottom navigation
  Onboarding/      The three first-launch screens
  Home/            Home screen and cards, four-tab shell (tabs stay alive between switches)
  Play/            Play lobby: Classic Mode, Time Challenge, Daily Challenge, previous run, Start Game
  Achievements/    Achievement definitions and "Royal Achievements" screen
  Profile/         Local profile: avatar, nickname, rank, statistics, preferences
  DailyChallenge/  Date-derived offline daily challenge
  Settings/        Shared preferences sections (used by Profile and the Home gear sheet), How to Play, Privacy
  Services/        Settings, progress and profile persistence; audio, haptics, tilt input
  Resources/       Asset catalog, sounds, PrivacyInfo.xcprivacy
CatchTheJewelsTests/    Unit tests
CatchTheJewelsUITests/  UI tests
Tools/                  Asset generation (artwork renderer, audio synthesizer)
Docs/                   App Store checklist and metadata draft
assets/                 Source background artwork
```

## Navigation

Four tabs, driven by `AppModel` (the single source of truth for the selected tab, lobby mode and active run):

| Tab | Screen |
| --- | --- |
| Home | Royal stage background, Play Now (opens the Play lobby), best score / jewels / games, daily challenge, latest achievement, gear → Settings sheet |
| Play | "Choose Your Challenge" lobby. Selecting a mode never starts a run; **Start Game** does |
| Achievements | "Royal Achievements": completion ring, empty state, locked/unlocked rows, NEW badges with an unlock animation |
| Profile | Avatar + nickname (edited locally), rank, all statistics, every preference, reset with confirmation |

## How the game works

- **Rules**: `GameSession` is a pure value type with no rendering code. The scene feeds it elapsed time and catches, and it reports outcomes. This is what the unit tests exercise.
- **Game loop**: `GameScene.update(_:)` is the only clock. It uses no repeating timers or SKActions for gameplay, so pausing just stops the clock and there's never more than one loop. Frame steps are clamped so objects can't tunnel through the crown after a hitch.
- **Pausing**: the game pauses automatically when the app becomes inactive or goes to the background, or when the game screen disappears. Choosing **Home** from the pause menu keeps the run suspended, and **Resume** appears on Home and Play.
- **Randomness**: a seeded SplitMix64 generator. Endless runs use a random seed. The daily challenge seed comes from the device's local date, so everyone gets the same jewels on the same day, offline.
- **Scoring**: ruby 10, sapphire 15, emerald 20, amethyst 30, gold star 50. Every 10 consecutive catches raise the multiplier, up to ×4. A missed jewel resets the combo but never costs a life. A bomb costs a life, followed by 1.2 seconds of protection. Rare hearts restore a life, or give +100 at full health.
- **Difficulty**: rises every 12 seconds of play: faster falls, shorter gaps, more bombs (capped at 30%) and new spawn patterns (pair, diagonal, shower).
- **Modes**: Classic (three lives, ends when they run out), Time Challenge (60 seconds, random seed), Daily Challenge (60 seconds, date seed, completion rewarded once per day).
- **Achievements**: 14 in total; the eight required ones come first. All are derived from saved statistics. Achievements reachable mid-run (e.g. First Catch) unlock the moment they happen with an in-game toast; the run's statistics are saved once, at game over.
- **No double counting**: every run has a UUID and `ProgressStore.record` ignores a run it has already saved.
- **Reset Game Progress** erases scores, statistics, achievements and daily records only — nickname, avatar and preferences are kept.
- **Persistence**: `UserDefaults` only. Settings are stored as individual keys. Progress is stored as one JSON document that decodes tolerantly: missing fields fall back to defaults, impossible values are repaired, and unreadable data resets cleanly instead of crashing.

## Assets

- **Background**: `assets/Regal Emerald Jewel Stage.png`, copied into the asset catalog as `RoyalStageBackground`. It's shown behind every screen (aspect fill, under a dark scrim for readability) and behind gameplay. To change it, replace `CatchTheJewels/Resources/Assets.xcassets/RoyalStageBackground.imageset/RoyalStageBackground.png`. Make sure you hold the rights to any artwork you ship.
- **App icon**: built from the supplied artwork `assets/AppIconSource.jpeg` by `Tools/make_app_icon.py`. The source is an icon mockup with its own rounded frame and white corners; the script repaints the corners with the frame's green and outputs an opaque, square 1024×1024 PNG so iOS can apply its own corner mask. To change the icon, replace `assets/AppIconSource.jpeg` (square, ideally 1024 px or larger) and run `./Tools/generate_assets.sh`.
- **Brand mark (launch screen and splash)**: `BrandMark` in the asset catalog — the same supplied artwork with rounded transparent corners at 1×/2×/3× (160 pt), generated by `Tools/make_app_icon.py --brand-mark`. The launch screen and the animated splash show it at the same size and position for a seamless hand-off.
- **Glass UI**: every card, chip, secondary button and HUD capsule uses `GlassBackground` (`DesignSystem/GlassBackground.swift`): frosted blur, emerald tint, glossy top highlight, shaded lower edge, light-catching rim and layered shadows. It becomes more opaque when the system Increase Contrast setting is on.
- **Jewels, bomb, heart and crown**: original vector drawings in `Artwork/ArtworkPainter.swift`, rendered at runtime for perfect sharpness.
- **Sound effects and music**: original, synthesized by `Tools/synthesize_audio.py`.
- To regenerate the icon, brand mark and audio, run `./Tools/generate_assets.sh`. It needs the Xcode command-line tools and Python 3 with Pillow (`pip3 install Pillow`).

## SDK integration and privacy

The app links `StorageQuotaManager.xcframework` and Adjust 5.6.2. The SDK can use networking and attribution identifiers, so App Store privacy answers and the hosted privacy policy must be reviewed against the SDK provider's current data-practice disclosure before submission. The app's own game progress remains local in `UserDefaults`, and the optional tilt control reads device motion locally.

See `Docs/AppStoreChecklist.md` for the release checklist and `Docs/AppStoreMetadata.md` for a draft listing.
