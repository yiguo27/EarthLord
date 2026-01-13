//
//  MoreTabView.swift
//  EarthLord
//
//  Created by Yiguo27 on 2026/1/10.
//

import SwiftUI

struct MoreTabView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Supabase 测试入口
                        NavigationLink(destination: SupabaseTestView()) {
                            MoreMenuRow(
                                icon: "server.rack",
                                title: "Supabase连接测试",
                                subtitle: "测试后端服务连接状态"
                            )
                        }

                        // 登出按钮
                        Button(action: {
                            showLogoutConfirm = true
                        }) {
                            MoreMenuRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "登出",
                                subtitle: "退出当前账号"
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.large)
            .alert("确认登出", isPresented: $showLogoutConfirm) {
                Button("取消", role: .cancel) { }
                Button("登出", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("确定要退出当前账号吗？")
            }
        }
    }
}

/// 更多页面菜单行组件
struct MoreMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 44, height: 44)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    MoreTabView()
}
