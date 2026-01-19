//
//  RootView.swift
//  EarthLord
//
//  Created by Yiguo27 on 2026/1/10.
//

import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
struct RootView: View {
    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 启动页是否完成
    @State private var splashFinished = false

    /// 是否已检查会话
    @State private var sessionChecked = false

    /// 🔧 Auth视图的稳定标识，防止重新创建
    @State private var authViewID = UUID()

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
                    .onAppear {
                        print("🖥️ RootView: 显示启动页")
                    }
            } else if !sessionChecked || authManager.isLoading {
                // 检查会话中
                sessionCheckingView
                    .transition(.opacity)
                    .onAppear {
                        print("🖥️ RootView: 显示会话检查中...")
                    }
            } else if authManager.isAuthenticated && !authManager.needsPasswordSetup {
                // 🔧 关键修复：已认证 且 不需要设置密码 → 主界面
                // 如果需要设置密码，即使技术上已登录，也继续显示认证页面
                MainTabView()
                    .transition(.opacity)
                    .onAppear {
                        print("🖥️ RootView: 显示主界面（已认证且密码已设置）")
                        print("   isAuthenticated: \(authManager.isAuthenticated)")
                        print("   needsPasswordSetup: \(authManager.needsPasswordSetup)")
                    }
            } else {
                // 未认证 或 需要设置密码 → 认证页面
                AuthView()
                    .id(authViewID)  // 🔧 保持视图实例稳定，防止重新创建导致状态重置
                    .transition(.opacity)
                    .onAppear {
                        print("🖥️ RootView: 显示认证页面")
                        print("   isAuthenticated: \(authManager.isAuthenticated)")
                        print("   needsPasswordSetup: \(authManager.needsPasswordSetup)")
                        print("   authViewID: \(authViewID)")
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: sessionChecked)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authManager.needsPasswordSetup)  // 🔧 也监听密码设置需求
        .onChange(of: splashFinished) { _, finished in
            if finished {
                print("🖥️ RootView: 启动页完成，开始检查会话")
                // 启动页完成后检查会话
                Task {
                    await authManager.checkSession()
                    sessionChecked = true
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            print("🖥️ RootView: isAuthenticated 变化: \(oldValue) -> \(newValue)")

            // 🔧 当认证状态从 true 变为 false（登出），重新生成 AuthView ID
            if oldValue == true && newValue == false {
                authViewID = UUID()
                print("   → 重新生成 authViewID: \(authViewID)")
            }
        }
        .onChange(of: authManager.needsPasswordSetup) { oldValue, newValue in
            print("🖥️ RootView: needsPasswordSetup 变化: \(oldValue) -> \(newValue)")
        }
    }

    /// 会话检查中视图
    private var sessionCheckingView: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.2)

                Text("正在检查登录状态...".localized)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }
}

#Preview {
    RootView()
}
