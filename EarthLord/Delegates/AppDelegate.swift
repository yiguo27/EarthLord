//
//  AppDelegate.swift
//  EarthLord
//
//  Created by Claude on 2026/1/27.
//

import UIKit
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // 处理 Google Sign-In 的 URL 回调
        return GIDSignIn.sharedInstance.handle(url)
    }
}
