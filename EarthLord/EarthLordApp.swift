//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 赵燕燕 on 2026/1/13.
//

import SwiftUI

@main
struct EarthLordApp: App {
    /// App Delegate（用于处理 Google Sign-In 等回调）
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// 全局定位管理器（作为环境对象注入，供所有视图共享）
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(locationManager)
                .onAppear {
                    // 启动玩家位置上报服务（用于附近玩家密度检测）
                    PlayerLocationManager.shared.start(with: locationManager)
                }
        }
    }
}
