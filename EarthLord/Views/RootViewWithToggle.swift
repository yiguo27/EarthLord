//
//  RootViewWithToggle.swift
//  EarthLord
//
//  带版本切换的根视图 - 方便对比新旧设计
//

import SwiftUI

/// 根视图（带设计版本切换）：控制启动页、认证页与主界面的切换
struct RootViewWithToggle: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var splashFinished = false
    @State private var sessionChecked = false
    @State private var authViewID = UUID()
    @State private var previousAuthState = false

    // 🎨 设计版本切换
    @AppStorage("useModernDesign") private var useModernDesign = true
    @State private var showVersionToggle = true

    var body: some View {
        ZStack {
            if !splashFinished {
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if !sessionChecked || authManager.isLoading {
                sessionCheckingView
                    .transition(.opacity)
            } else if authManager.isAuthenticated && !authManager.needsPasswordSetup {
                MainTabView()
                    .transition(.opacity)
            } else {
                // 🎨 根据设置选择使用哪个版本的认证界面
                Group {
                    if useModernDesign {
                        ModernAuthView()
                    } else {
                        AuthView()
                    }
                }
                .id(authViewID)
                .transition(.opacity)
            }

            // 🎨 版本切换按钮（仅在认证页面显示）
            if splashFinished && sessionChecked && !authManager.isAuthenticated && showVersionToggle {
                versionToggleButton
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: sessionChecked)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authManager.needsPasswordSetup)
        .onChange(of: splashFinished) { finished in
            if finished {
                Task {
                    await authManager.checkSession()
                    sessionChecked = true
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { newValue in
            if previousAuthState == true && newValue == false {
                authViewID = UUID()
            }
            previousAuthState = newValue
        }
    }

    // MARK: - 版本切换按钮
    private var versionToggleButton: some View {
        VStack {
            HStack {
                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        useModernDesign.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: useModernDesign ? "sparkles" : "paintbrush.fill")
                            .font(.system(size: 14))

                        Text(useModernDesign ? "新版设计" : "旧版设计")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: useModernDesign ?
                                        [ApocalypseTheme.primary, ApocalypseTheme.primaryDark] :
                                        [Color.gray, Color.gray.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: useModernDesign ? ApocalypseTheme.primary.opacity(0.3) : Color.black.opacity(0.2),
                                    radius: 8, y: 4)
                    )
                }
                .padding(.trailing, 20)
                .padding(.top, 60)
            }

            Spacer()
        }
    }

    // MARK: - 会话检查中视图
    private var sessionCheckingView: some View {
        ZStack {
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
    RootViewWithToggle()
}
