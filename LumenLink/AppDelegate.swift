//
//  AppDelegate.swift
//  LumenLink
//
//  App entry point and lifecycle.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let hasOnboarded = UserDefaults.standard.bool(forKey: "has_onboarded")
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .systemBackground

        if hasOnboarded {
            let mainVC = MainViewController()
            let nav = UINavigationController(rootViewController: mainVC)
            window.rootViewController = nav
        } else {
            let onboardingVC = OnboardingViewController()
            onboardingVC.onComplete = { [weak window] in
                UserDefaults.standard.set(true, forKey: "has_onboarded")
                let mainVC = MainViewController()
                let nav = UINavigationController(rootViewController: mainVC)
                window?.rootViewController = nav
            }
            window.rootViewController = onboardingVC
        }

        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}
