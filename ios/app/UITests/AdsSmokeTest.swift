import XCTest

/// Ads really load and show (Google demo units). Runs WITHOUT -uitest so the ad SDK starts.
/// Needs network. Not part of the dead-control audit.
final class AdsSmokeTest: XCTestCase {

    func testRewardedTestAdShows() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset"]
        app.launch()

        // Google's demo App ID ships an "IDFA explainer" consent message, then the system ATT
        // alert. (Our real App ID must NOT publish that message — APP-STORE-REVIEW.md ⛔1.)
        let cont = app.webViews.buttons["Continue"].firstMatch
        if cont.waitForExistence(timeout: 15) { cont.tap() }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["Ask App Not to Track"]
        if deny.waitForExistence(timeout: 8) { deny.tap() }

        let coin = app.buttons["coins.button"]
        XCTAssertTrue(coin.waitForExistence(timeout: 10))
        coin.tap()

        let watch = app.buttons["coins.watch"]
        XCTAssertTrue(watch.waitForExistence(timeout: 10), "watch button missing — ad SDK did not start (consent?)")
        let ready = NSPredicate(format: "isEnabled == true")
        expectation(for: ready, evaluatedWith: watch)
        waitForExpectations(timeout: 30)          // demo ad download
        watch.tap()

        // The demo creative is a full-screen web view; the sheet is covered by it.
        sleep(5)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "rewarded-test-ad"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertFalse(app.staticTexts["coins.balance"].isHittable, "rewarded ad did not cover the screen")
    }
}
