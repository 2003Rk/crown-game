# Release Checklist — Catch the Jewels

Status key: ✅ done and verified in this repo · 🔲 must be done manually (needs Xcode, a device, an Apple Developer account or App Store Connect)

App Store approval is never guaranteed. This list follows the current App Review Guidelines as of writing; re-read them before submitting.

## Build
- ✅ App, unit-test and UI-test bundles compile (`build-for-testing`, generic simulator destination) with no Swift warnings
- ✅ Release build for generic iOS device compiles (unsigned)
- 🔲 Run unit tests — the original 81 passed before the four-tab update; the updated suite has **not yet been executed**
- 🔲 Run UI tests (`-only-testing:CatchTheJewelsUITests`) — written but **not yet executed**
- 🔲 Set `APP_BUNDLE_IDENTIFIER` and `APP_DEVELOPMENT_TEAM` in `Config/Base.xcconfig`
- 🔲 Archive (Any iOS Device) and validate in Organizer
- 🔲 Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` per upload

## Crashes & stability (on physical devices)
- 🔲 Fresh install → onboarding → Start Playing → game over → Home
- 🔲 Returning user: onboarding not shown; best score/achievements retained
- 🔲 Background the app mid-run → returns paused; no audio continues
- 🔲 Incoming call / Control Center / Siri mid-run → game pauses
- 🔲 Pause → Home → Resume from Home and from Play tab
- 🔲 All four tabs keep their scroll position and state when switching
- 🔲 Play Now / Daily card / achievement card / gear button each open the right place
- 🔲 Edit nickname and avatar, relaunch, confirm they persist
- 🔲 Rapid double-tap on Play doesn't start two games
- 🔲 Force-quit mid-run and relaunch → no crash (suspended runs are intentionally not restored)
- 🔲 Reset Game Progress (keeps nickname, avatar, settings) and Replay Tutorial both work and confirm first
- 🔲 Check Xcode Organizer crash reports after TestFlight

## Performance
- 🔲 Profile with Instruments (Time Profiler, Allocations) on the oldest supported device; target steady 60 fps at max difficulty
- 🔲 Play 5+ minutes: memory stays flat (no leaked nodes or emitters)

## Layout
- 🔲 iPhone SE (3rd gen), iPhone 17 Pro Max, iPad mini, iPad Pro 13" (portrait + landscape), Stage Manager / Split View on iPad
- 🔲 Background image fills every screen without letterboxing; text readable over it
- 🔲 Largest Dynamic Type size (Accessibility XXXL) on menus: nothing clipped

## Accessibility
- ✅ VoiceOver labels/values on all controls, HUD score/lives/timer, achievements
- ✅ Jewels/bomb/heart distinguishable by shape and symbol, not color alone
- ✅ Reduce Motion (system and in-app) disables shake, particles intensity and decorative animation
- ✅ Larger Crown and sensitivity options; 44pt+ touch targets
- 🔲 Full VoiceOver pass on device; Accessibility Inspector audit

## SDK & privacy
- ✅ StorageQuotaManager SDK linked for device and Apple-silicon simulator builds
- ✅ Adjust 5.6.2, required system frameworks, linker flags and SKAdNetwork IDs configured
- 🔲 Obtain the SDK provider's data-practice disclosure and update `PrivacyInfo.xcprivacy` if required
- 🔲 Match App Store Connect privacy answers and the hosted privacy policy to the final SDK behavior
- ✅ No permission prompts (tilt uses device motion, which needs none)
- 🔲 Verify in Airplane Mode on device
- 🔲 Complete App Privacy in App Store Connect using the verified SDK disclosures
- 🔲 Host a privacy policy URL and support URL

## Audio & haptics
- 🔲 Silent switch on → no game audio; other apps' music keeps playing (ambient category)
- 🔲 Music/SFX/Haptics toggles take effect immediately, including from the pause menu

## Content & guidelines
- ✅ No gambling, betting, casino imagery or terminology; no real-money rewards; no purchases
- ✅ No placeholder screens; every tab and button is functional
- ✅ Test hooks compiled only in DEBUG; no debug menus in Release
- 🔲 Confirm you hold the rights to `assets/Regal Emerald Jewel Stage.png` and any replacement branding
- 🔲 Screenshots captured from the real build (see `AppStoreMetadata.md`) — **not yet produced**
- 🔲 Age rating questionnaire completed (expected 4+)

## StoreKit
- ✅ No In-App Purchase capability, entitlement, purchase code or monetization UI
- ✅ The supplied SDK handles its optional StoreKit attribution linkage automatically
