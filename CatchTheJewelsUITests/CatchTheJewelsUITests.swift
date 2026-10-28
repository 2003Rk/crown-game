import XCTest

final class CatchTheJewelsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helpers

    private func launch(fresh: Bool = true, skipOnboarding: Bool = true, scenario: String? = nil) {
        var arguments = ["-skipSplash"]
        if fresh { arguments.append("-resetState") }
        if skipOnboarding { arguments.append("-skipOnboarding") }
        if let scenario { arguments += ["-scenario", scenario] }
        app.launchArguments = arguments
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @discardableResult
    private func waitFor(_ identifier: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing \(identifier)", file: file, line: line)
        return target
    }

    private func waitForDisappearance(_ identifier: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element(identifier))
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, "\(identifier) still visible", file: file, line: line)
    }

    private func tap(_ identifier: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let target = waitFor(identifier, timeout: timeout, file: file, line: line)
        scrollIntoView(target)
        target.tap()
    }

    private func scrollIntoView(_ target: XCUIElement) {
        var attempts = 0
        while !target.isHittable && attempts < 8 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
    }

    private func value(of identifier: String) -> String? {
        waitFor(identifier).value as? String
    }

    /// Opens the Play lobby, picks a mode and starts it, waiting out the countdown.
    private func start(mode: String = "classic") {
        tap("tab.play")
        tap("mode.\(mode)")
        tap("play.start")
        waitFor("hud.pause")
        waitForDisappearance("game.countdown", timeout: 8)
    }

    private func toggleSwitch(_ identifier: String) {
        let toggle = waitFor(identifier)
        scrollIntoView(toggle)
        toggle.switches.firstMatch.tap()
    }

    // MARK: - Onboarding

    func testFirstLaunchOnboardingContinueBackAndStart() {
        launch(fresh: true, skipOnboarding: false)

        waitFor("onboarding.headline.0")
        XCTAssertTrue(app.staticTexts["Your Jewel Hunt Begins"].exists)
        XCTAssertTrue(element("onboarding.skip").exists)
        XCTAssertFalse(element("onboarding.back").exists, "No Back on the first screen")

        tap("onboarding.continue")
        waitFor("onboarding.headline.1")
        tap("onboarding.back")
        waitFor("onboarding.headline.0")

        tap("onboarding.continue")
        tap("onboarding.continue")
        waitFor("onboarding.headline.2")
        XCTAssertFalse(element("onboarding.skip").exists, "No Skip on the last screen")

        tap("onboarding.start")
        // "Start Playing" opens the game lobby rather than starting a run outright.
        waitFor("play.start")
        XCTAssertFalse(element("hud.pause").exists)

        // Returning user: onboarding is not shown again.
        app.terminate()
        launch(fresh: false, skipOnboarding: false)
        waitFor("home.playNow")
        XCTAssertFalse(element("onboarding").exists)
    }

    func testSkipOnboardingOpensHome() {
        launch(fresh: true, skipOnboarding: false)
        tap("onboarding.skip")
        waitFor("home.playNow")
        waitFor("home.headline")
        XCTAssertFalse(element("hud.pause").exists, "Skip doesn't start a game")
    }

    func testReplayTutorialFromProfile() {
        launch()
        tap("tab.profile")
        tap("settings.resetTutorial")
        let confirm = app.buttons["Replay Tutorial"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        waitFor("onboarding.headline.0")
    }

    // MARK: - Navigation

    func testAllFourTabsOpenFunctionalScreens() {
        launch()
        waitFor("home.playNow")
        XCTAssertTrue(element("tab.home").isSelected)

        tap("tab.play")
        waitFor("play.title")
        waitFor("mode.classic")
        XCTAssertTrue(element("tab.play").isSelected)

        tap("tab.achievements")
        waitFor("achievements.unlockedCount")
        waitFor("achievements.empty")

        tap("tab.profile")
        waitFor("profile.nickname")
        XCTAssertEqual(element("profile.nickname").label, "Royal Player")

        tap("tab.home")
        waitFor("home.playNow")
    }

    func testHomePlayNowOpensLobbyWithoutStartingAGame() {
        launch()
        tap("home.playNow")
        waitFor("play.start")
        XCTAssertTrue(element("tab.play").isSelected)
        XCTAssertFalse(element("hud.pause").exists)
    }

    func testHomeShortcuts() {
        launch()
        tap("home.settings")
        waitFor("settings.music")
        tap("settings.done")
        waitForDisappearance("settings.done")

        tap("home.achievementCard")
        waitFor("achievements.unlockedCount")

        tap("tab.home")
        tap("daily.open")
        waitFor("play.start")
        XCTAssertTrue(element("mode.daily").isSelected, "The daily card selects the Daily Challenge mode")
    }

    func testModeSelectionStartsTheChosenMode() {
        launch()
        tap("tab.play")
        tap("mode.timeChallenge")
        XCTAssertTrue(element("mode.timeChallenge").isSelected)
        XCTAssertFalse(element("mode.classic").isSelected)
        tap("play.start")
        waitFor("hud.timer")

        tap("hud.pause")
        tap("pause.home")
        tap("resume.abandon")

        tap("tab.play")
        tap("mode.daily")
        tap("play.start")
        waitFor("hud.timer")
    }

    // MARK: - Gameplay

    func testStartPauseAndResume() {
        launch()
        start()
        tap("hud.pause")
        waitFor("pause.title")
        tap("pause.resume")
        waitForDisappearance("pause.title")
        XCTAssertTrue(element("hud.score").exists)
    }

    func testGameOverPlayAgainAndStatisticsUpdate() {
        launch(scenario: "bombsOnly")
        XCTAssertEqual(value(of: "home.stat.games"), "0")
        start()

        waitFor("gameover.title", timeout: 45)
        waitFor("gameover.score")
        XCTAssertEqual(element("hud.lives").value as? String, "0 of 3")

        tap("gameover.playAgain")
        waitForDisappearance("gameover.title")
        XCTAssertEqual(element("hud.lives").value as? String, "3 of 3")
        XCTAssertEqual(element("hud.score").value as? String, "0")

        waitFor("gameover.title", timeout: 45)
        tap("gameover.home")
        waitFor("home.playNow")
        XCTAssertFalse(element("resume.run").exists, "Finished runs can't be resumed")
        XCTAssertEqual(value(of: "home.stat.games"), "2", "Home reflects both recorded runs")

        tap("tab.profile")
        XCTAssertEqual(value(of: "profile.stat.games"), "2", "Profile agrees with Home")

        tap("tab.play")
        waitFor("play.lastRun")
    }

    func testRestartFromPauseMenu() {
        launch()
        start()
        tap("hud.pause")
        tap("pause.restart")
        waitForDisappearance("pause.title")
        waitFor("game.countdown")
        XCTAssertEqual(element("hud.lives").value as? String, "3 of 3")
    }

    func testPauseHomeThenResumeFromPlayTab() {
        launch()
        start()
        tap("hud.pause")
        tap("pause.home")

        waitFor("home.playNow")
        waitFor("resume.run")

        tap("tab.play")
        tap("resume.run")
        waitFor("pause.title")
        tap("pause.resume")
        waitForDisappearance("pause.title")
    }

    func testBackgroundingPausesTheGame() {
        launch()
        start()

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        waitFor("pause.title")
        tap("pause.resume")
        waitForDisappearance("pause.title")
    }

    // MARK: - Profile & settings

    func testNicknameAndAvatarPersistAcrossLaunches() {
        launch()
        tap("tab.profile")
        tap("profile.edit")
        let field = waitFor("profile.nicknameField")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        field.typeText("Queen Ruby")
        tap("avatar.sapphire")
        tap("profile.save")
        XCTAssertEqual(waitFor("profile.nickname").label, "Queen Ruby")

        app.terminate()
        launch(fresh: false)
        tap("tab.profile")
        XCTAssertEqual(waitFor("profile.nickname").label, "Queen Ruby")
    }

    func testSettingsTogglesPersistAcrossLaunches() {
        launch()
        tap("tab.profile")
        XCTAssertEqual(value(of: "settings.sound"), "1")
        toggleSwitch("settings.sound")
        XCTAssertEqual(value(of: "settings.sound"), "0")
        toggleSwitch("settings.haptics")
        XCTAssertEqual(value(of: "settings.haptics"), "0")

        app.terminate()
        launch(fresh: false)
        tap("tab.profile")
        XCTAssertEqual(value(of: "settings.sound"), "0")
        XCTAssertEqual(value(of: "settings.haptics"), "0")
    }

    func testResetProgressRequiresConfirmation() {
        launch(scenario: "bombsOnly")
        start()
        waitFor("gameover.title", timeout: 45)
        tap("gameover.home")

        tap("tab.profile")
        XCTAssertEqual(value(of: "profile.stat.games"), "1")

        tap("settings.resetProgress")
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertEqual(value(of: "profile.stat.games"), "1", "Cancel keeps progress")

        tap("settings.resetProgress")
        let confirm = app.buttons["Reset Progress"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertEqual(value(of: "profile.stat.games"), "0")
        XCTAssertEqual(element("profile.nickname").label, "Royal Player", "Profile survives a progress reset")
    }

    func testPrivacyAndVersionAreShown() {
        launch()
        tap("tab.profile")
        tap("settings.privacy")
        XCTAssertTrue(app.staticTexts["No Data Collected"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let version = waitFor("settings.version")
        scrollIntoView(version)
        XCTAssertTrue(version.exists)
    }
}
