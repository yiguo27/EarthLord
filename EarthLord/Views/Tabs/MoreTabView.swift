import SwiftUI
import Supabase

struct MoreTabView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 用户信息卡片
                        userInfoCard
                            .padding(.top, 20)

                        // 功能列表
                        settingsSection

                        // 退出登录按钮
                        logoutButton
                            .padding(.top, 20)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("个人中心")
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

    // MARK: - 用户信息卡片
    private var userInfoCard: some View {
        VStack(spacing: 16) {
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
                    .frame(width: 80, height: 80)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)

                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // 用户名
            Text(authManager.currentUser?.email ?? "未登录")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 用户 ID
            if let userId = authManager.currentUser?.id {
                Text("ID: \(userId.uuidString.prefix(8))...")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 设置列表
    private var settingsSection: some View {
        VStack(spacing: 0) {
            SettingRow(
                icon: "person.circle",
                title: "账号信息",
                iconColor: ApocalypseTheme.primary
            ) {
                // TODO: 跳转到账号信息页面
            }

            Divider()
                .padding(.leading, 56)

            SettingRow(
                icon: "bell.badge",
                title: "通知设置",
                iconColor: .orange
            ) {
                // TODO: 跳转到通知设置页面
            }

            Divider()
                .padding(.leading, 56)

            SettingRow(
                icon: "lock.shield",
                title: "隐私与安全",
                iconColor: .blue
            ) {
                // TODO: 跳转到隐私设置页面
            }

            Divider()
                .padding(.leading, 56)

            SettingRow(
                icon: "info.circle",
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

// MARK: - 设置行组件
struct SettingRow: View {
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
    MoreTabView()
}
