import XCTest

final class WeldingGasWalletUITests: XCTestCase {
    private let argonID = "20000000-0000-0000-0000-000000000001"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLegalOnboardingHasOneExplicitGate() {
        let app = launch(onboardingComplete: false, screenshotData: false)
        let acceptance = app.buttons["shell.onboarding.accept"]
        let primary = app.buttons["shell.onboarding.primary"]
        XCTAssertTrue(acceptance.waitForExistence(timeout: 8))
        XCTAssertFalse(primary.isEnabled)
        acceptance.tap()
        XCTAssertTrue(primary.isEnabled)
    }

    func testPaywallExposesPurchaseAndRestoreControls() {
        let app = launch()
        openSettings(app)
        tap(app, identifier: "shell.settings.upgrade", label: "Upgrade")
        XCTAssertTrue(app.scrollViews["shell.paywall"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["shell.paywall.restore"].exists)
    }

    func testPrimaryControlsMeetMinimumHitTarget() {
        let app = launch(onboardingComplete: false, screenshotData: false)
        let control = app.buttons["shell.onboarding.accept"]
        XCTAssertTrue(control.waitForExistence(timeout: 8))
        XCTAssertGreaterThanOrEqual(control.frame.height, 44)
        XCTAssertGreaterThanOrEqual(control.frame.width, 44)
    }

    func testCaptureAllScreens() throws {
        try scenario(1, "Onboarding", onboardingComplete: false) { app in
            XCTAssertTrue(app.buttons["shell.onboarding.primary"].waitForExistence(timeout: 8))
        }
        try scenario(2, "Cylinders-Home") { app in waitForHome(app) }
        try scenario(3, "Cylinder-Status-Controls") { app in
            waitForHome(app)
            tap(app, identifier: "wallet.status.\(argonID)", label: "Change Argon status")
            XCTAssertTrue(app.staticTexts["Update status"].waitForExistence(timeout: 5))
        }
        try scenario(4, "Add-Cylinder") { app in
            waitForHome(app)
            tap(app, identifier: "wallet.addCylinder", label: "Add cylinder")
            waitForNavigationTitle(app, "Add cylinder")
        }
        try scenario(5, "Add-Supplier-Inline") { app in
            waitForHome(app)
            tap(app, identifier: "wallet.addCylinder", label: "Add cylinder")
            tap(app, label: "Add supplier, relationship or serial")
            tap(app, label: "Add supplier")
            waitForNavigationTitle(app, "Add supplier")
        }
        try scenario(6, "Cylinder-Detail") { app in openArgon(app) }
        try scenario(7, "Record-Refill") { app in
            openArgon(app); tap(app, label: "Refill"); waitForNavigationTitle(app, "Refill")
        }
        try scenario(8, "Exchange-Cylinder") { app in
            openArgon(app); tap(app, label: "Exchange"); waitForNavigationTitle(app, "Exchange")
        }
        try scenario(9, "Add-Cost") { app in
            openArgon(app); tap(app, label: "Add cost"); waitForNavigationTitle(app, "Cost")
        }
        try scenario(10, "Set-Reminder") { app in
            openArgon(app); tap(app, containing: "Reminder"); waitForNavigationTitle(app, "Reminder")
        }
        try scenario(11, "Edit-Cylinder") { app in
            openArgon(app); tap(app, label: "Edit"); waitForNavigationTitle(app, "Edit cylinder")
        }
        try scenario(12, "Delete-Cylinder-Confirmation") { app in
            openArgon(app); tap(app, label: "Edit"); tap(app, label: "Delete cylinder")
            XCTAssertTrue(app.buttons["Delete cylinder and history"].waitForExistence(timeout: 5))
        }
        try scenario(13, "Archive-Cylinder-Confirmation") { app in
            openArgon(app); tap(app, label: "Return or archive"); tap(app, label: "Archive cylinder")
            XCTAssertTrue(app.buttons["Archive cylinder"].waitForExistence(timeout: 5))
        }
        try scenario(14, "Activity") { app in
            openTab(app, "Activity")
            XCTAssertTrue(app.staticTexts["Total spent"].waitForExistence(timeout: 8))
        }
        try scenario(15, "Suppliers") { app in
            openTab(app, "Suppliers")
            XCTAssertTrue(app.staticTexts["Linde Canada"].waitForExistence(timeout: 8))
        }
        try scenario(16, "Supplier-Detail") { app in
            openTab(app, "Suppliers"); tap(app, label: "Linde Canada"); waitForNavigationTitle(app, "Linde Canada")
        }
        try scenario(17, "Add-Supplier") { app in
            openTab(app, "Suppliers"); tap(app, identifier: "wallet.addSupplier", label: "Add supplier"); waitForNavigationTitle(app, "Add supplier")
        }
        try scenario(18, "Settings") { app in openSettings(app) }
        try scenario(19, "Upgrade-to-Pro") { app in
            openSettings(app); tap(app, identifier: "shell.settings.upgrade", label: "Upgrade")
            XCTAssertTrue(app.scrollViews["shell.paywall"].waitForExistence(timeout: 8))
        }
        try scenario(20, "Language") { app in
            openSettings(app); tap(app, label: "Language"); waitForNavigationTitle(app, "Language")
        }
        try scenario(21, "Currency") { app in
            openSettings(app); tap(app, label: "Currency"); waitForNavigationTitle(app, "Currency")
        }
        try scenario(22, "Backup") { app in
            openSettings(app); tap(app, label: "Backup"); waitForNavigationTitle(app, "Backup")
        }
        try scenario(23, "Help") { app in
            openSettings(app); tap(app, label: "Help"); waitForNavigationTitle(app, "Help")
        }
        try scenario(24, "Delete-All-Data-Confirmation") { app in
            openSettings(app); tap(app, label: "Delete all data")
            XCTAssertTrue(app.alerts["Delete all data?"].waitForExistence(timeout: 5))
        }
    }

    private func launch(onboardingComplete: Bool = true, screenshotData: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_CA",
            "-shell.onboarding.complete", onboardingComplete ? "YES" : "NO",
            "-shell.legal.acceptedVersion", onboardingComplete ? "1" : "",
        ]
        if screenshotData { app.launchArguments += ["-welding.screenshotData", "YES"] }
        if screenshotData && !onboardingComplete { app.launchArguments += ["-welding.screenshotOnboarding", "YES"] }
        app.launch()
        return app
    }

    private func scenario(
        _ number: Int,
        _ label: String,
        onboardingComplete: Bool = true,
        navigation: (XCUIApplication) -> Void
    ) throws {
        let app = launch(onboardingComplete: onboardingComplete)
        navigation(app)
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
        try saveScreenshot(number: number, label: label)
        app.terminate()
    }

    private func saveScreenshot(number: Int, label: String) throws {
        let name = String(format: "%02d-%@.png", number, label)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForHome(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["3 active cylinders"].waitForExistence(timeout: 8))
    }

    private func openArgon(_ app: XCUIApplication) {
        waitForHome(app)
        tap(app, label: "Argon")
        waitForNavigationTitle(app, "Argon")
    }

    private func openTab(_ app: XCUIApplication, _ label: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing \(label) tab")
        tab.tap()
    }

    private func openSettings(_ app: XCUIApplication) {
        waitForHome(app)
        let settings = app.buttons["shell.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()
        waitForNavigationTitle(app, "Settings")
    }

    private func waitForNavigationTitle(_ app: XCUIApplication, _ title: String) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), "Missing navigation title: \(title)")
    }

    private func tap(_ app: XCUIApplication, identifier: String, label: String) {
        let identified = app.buttons[identifier]
        if identified.waitForExistence(timeout: 3) { identified.tap(); return }
        tap(app, label: label)
    }

    private func tap(_ app: XCUIApplication, label: String) {
        let exactButton = app.buttons[label].firstMatch
        if exactButton.waitForExistence(timeout: 3) { exactButton.tap(); return }
        let exactText = app.staticTexts[label].firstMatch
        XCTAssertTrue(exactText.waitForExistence(timeout: 5), "Missing control: \(label)")
        exactText.tap()
    }

    private func tap(_ app: XCUIApplication, containing text: String) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let button = app.buttons.matching(predicate).firstMatch
        if button.waitForExistence(timeout: 3) { button.tap(); return }
        let label = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5), "Missing control containing: \(text)")
        label.tap()
    }
}
