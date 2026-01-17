//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by Yiguo27 on 2026/1/10.
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 幸存者档案卡片
                        survivorProfileCard
                            .padding(.top, 20)

                        // 数据统计卡片
                        statsCard
                            .padding(.vertical, -5)

                        // 功能列表
                        functionsCard

                        // 退出登录按钮
                        logoutButton
                            .padding(.top, 10)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("个人")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("确定要退出登录吗？", isPresented: $showLogoutConfirm) {
                Button("退出登录", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后需要重新登录")
            }
        }
    }

    // MARK: - 幸存者档案
    private var survivorProfileCard: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("幸存者档案")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 用户信息
            HStack(spacing: 16) {
                // 头像
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)

                    Image(systemName: "person.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.white)
                }

                // 信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(authManager.currentUser?.email ?? "未登录")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    if let userId = authManager.currentUser?.id {
                        Text("ID: \(userId.uuidString.prefix(8))...")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    // 等级徽章
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.warning)

                        Text("Lv.1 新手幸存者")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()
            }
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 数据统计
    private var statsCard: some View {
        VStack(spacing: 8) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("生存数据")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 统计网格
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    StatItem(
                        icon: "flag.fill",
                        title: "领地",
                        value: "0",
                        color: ApocalypseTheme.primary
                    )

                    StatItem(
                        icon: "mappin.circle.fill",
                        title: "资源点",
                        value: "0",
                        color: .orange
                    )
                }

                HStack(spacing: 6) {
                    StatItem(
                        icon: "location.fill",
                        title: "探索距离",
                        value: "0 km",
                        color: .green
                    )

                    StatItem(
                        icon: "clock.fill",
                        title: "生存天数",
                        value: "1",
                        color: .blue
                    )
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 功能列表
    private var functionsCard: some View {
        VStack(spacing: 0) {
            ProfileFunctionRow(
                icon: "gearshape.fill",
                title: "设置",
                iconColor: ApocalypseTheme.primary
            ) {
                // TODO: 跳转到设置页面
            }

            Divider()
                .padding(.leading, 56)

            ProfileFunctionRow(
                icon: "bell.badge.fill",
                title: "通知",
                iconColor: .orange
            ) {
                // TODO: 跳转到通知页面
            }

            Divider()
                .padding(.leading, 56)

            ProfileFunctionRow(
                icon: "questionmark.circle.fill",
                title: "帮助",
                iconColor: .blue
            ) {
                // TODO: 跳转到帮助页面
            }

            Divider()
                .padding(.leading, 56)

            ProfileFunctionRow(
                icon: "info.circle.fill",
                title: "关于",
                iconColor: .gray
            ) {
                // TODO: 跳转到关于页面
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 退出登录按钮
    private var logoutButton: some View {
        Button(action: {
            showLogoutConfirm = true
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))

                Text("退出登录")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.danger.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 统计项组件
private struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }

            // 数值
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 标题
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - 功能行组件
private struct ProfileFunctionRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }

                // 标题
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    ProfileTabView()
}
