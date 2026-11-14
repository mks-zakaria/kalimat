import Foundation
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency
import UIKit
import Observation

/// The only file that knows the ad SDK (replica/ads-mediation.md: swapping to MAX later
/// touches this file only).
///
/// Order, per Google's rules: UMP consent → (if ads may be requested) start the SDK →
/// load ads. The ATT prompt is separate and only fires after the first finished level,
/// straight from that moment (APP-STORE-REVIEW.md ⛔1: no screen in front of it).
///
/// Ad policy (replica/architecture.md §3):
/// - rewarded: only when the player taps "watch for coins"
/// - interstitial: only between levels, ≥ 3 levels and ≥ 180 s apart, never before level 4
@MainActor
@Observable
final class AdService: NSObject {
    static let shared = AdService()

    // Google's published iOS demo units (developers.google.com/admob/ios/test-ads).
    // Replace with the real units from the AdMob console before release.
    enum Unit {
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    }
    static let rewardCoins = 25
    static let interstitialEveryLevels = 3
    static let interstitialMinSeconds: TimeInterval = 180
    static let firstInterstitialAfterLevel = 3

    private(set) var canRequestAds = false
    private(set) var rewardedReady = false
    private(set) var privacyOptionsRequired = false

    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var levelsSinceInterstitial = 0
    private var lastInterstitial = Date.distantPast
    private var started = false
    private var onRewardedClosed: (() -> Void)?

    /// UI tests pass `-uitest` (debug builds only) so no consent form, ATT alert or ad
    /// covers the screen they are checking.
    private var isUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        false
        #endif
    }

    // MARK: start

    func start() {
        guard !started, !isUITest else { return }
        started = true
        let params = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] error in
            if let error { print("[Ads] consent info update failed: \(error)") }
            Task { @MainActor in
                guard let self else { return }
                if let root = Self.topViewController() {
                    try? await ConsentForm.loadAndPresentIfRequired(from: root)
                }
                self.privacyOptionsRequired =
                    ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                self.startSDKIfAllowed()
            }
        }
        // Consent from a previous launch may already allow ads.
        startSDKIfAllowed()
    }

    private func startSDKIfAllowed() {
        print("[Ads] consentStatus=\(ConsentInformation.shared.consentStatus.rawValue) canRequestAds=\(ConsentInformation.shared.canRequestAds)")
        guard ConsentInformation.shared.canRequestAds, !canRequestAds else { return }
        canRequestAds = true
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                self?.loadRewarded()
                self?.loadInterstitial()
            }
        }
    }

    /// Lets the player change their consent choices (required in some regions).
    func showPrivacyOptions() {
        guard let root = Self.topViewController() else { return }
        Task { try? await ConsentForm.presentPrivacyOptionsForm(from: root) }
    }

    /// Asked once, after the first finished level. No pre-screen.
    func requestTrackingIfNeeded() {
        guard !isUITest, ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        ATTrackingManager.requestTrackingAuthorization { _ in }
    }

    // MARK: rewarded

    private func loadRewarded() {
        guard canRequestAds else { return }
        rewardedReady = false
        RewardedAd.load(with: Unit.rewarded, request: Request()) { [weak self] ad, error in
            if let error { print("[Ads] rewarded load failed: \(error)") } else { print("[Ads] rewarded loaded") }
            Task { @MainActor in
                guard let self else { return }
                self.rewarded = ad
                self.rewarded?.fullScreenContentDelegate = self
                self.rewardedReady = ad != nil
            }
        }
    }

    /// Shows a rewarded ad; `earned` runs only if the player watched it through.
    func showRewarded(earned: @escaping () -> Void, closed: (() -> Void)? = nil) {
        guard let ad = rewarded, let root = Self.topViewController() else { return }
        onRewardedClosed = closed
        ad.present(from: root) { earned() }
    }

    // MARK: interstitial

    private func loadInterstitial() {
        guard canRequestAds else { return }
        InterstitialAd.load(with: Unit.interstitial, request: Request()) { [weak self] ad, _ in
            Task { @MainActor in
                guard let self else { return }
                self.interstitial = ad
                self.interstitial?.fullScreenContentDelegate = self
            }
        }
    }

    /// Call when the player leaves a finished level. Shows an interstitial only if the
    /// frequency rules allow it; otherwise does nothing.
    func levelFinished(levelNumber: Int, adsRemoved: Bool) {
        levelsSinceInterstitial += 1
        guard !adsRemoved, !isUITest,
              levelNumber > Self.firstInterstitialAfterLevel,
              levelsSinceInterstitial >= Self.interstitialEveryLevels,
              Date().timeIntervalSince(lastInterstitial) >= Self.interstitialMinSeconds,
              let ad = interstitial, let root = Self.topViewController() else { return }
        levelsSinceInterstitial = 0
        lastInterstitial = Date()
        ad.present(from: root)
    }

    // MARK: helpers

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var vc = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}

extension AdService: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            if ad is RewardedAd {
                self.onRewardedClosed?(); self.onRewardedClosed = nil
                self.loadRewarded()
            } else {
                self.loadInterstitial()
            }
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            if ad is RewardedAd { self.loadRewarded() } else { self.loadInterstitial() }
        }
    }
}
