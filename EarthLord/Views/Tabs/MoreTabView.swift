import SwiftUI
import Supabase

struct MoreTabView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showLogoutConfirm = false
    @State private var showLanguagePicker = false

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
            .navigationTitle(languageManager.localizedString("个人中心"))
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                languageManager.localizedString("确定要退出登录吗？"),
                isPresented: $showLogoutConfirm
            ) {
                Button(languageManager.localizedString("退出登录"), role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
                Button(languageManager.localizedString("取消"), role: .cancel) {}
            } message: {
                Text(languageManager.localizedString("退出后需要重新登录"))
            }
            .sheet(isPresented: $showLanguagePicker) {
                languagePickerSheet
            }
        }
    }

    // MARK: - 语言选择弹窗
    private var languagePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                    Button(action: {
                        languageManager.setLanguage(language)
                        showLanguagePicker = false
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(ApocalypseTheme.primary.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: language.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(ApocalypseTheme.primary)
                            }
                            Text(language.displayName)
                                .font(.system(size: 16))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Spacer()
                            if languageManager.currentLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(ApocalypseTheme.primary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    if language != AppLanguage.allCases.last {
                        Divider().padding(.leading, 76)
                    }
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ApocalypseTheme.background)
            .navigationTitle(languageManager.localizedString("语言"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(languageManager.localizedString("取消")) {
                        showLanguagePicker = false
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 用户信息卡片
    private var userInfoCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.7)],
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
            Text(authManager.currentUser?.email ?? languageManager.localizedString("未登录"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
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
            // 语言设置
            SettingRowWithValue(
                icon: "globe",
                title: languageManager.localizedString("语言"),
                value: languageManager.currentLanguage.displayName,
                iconColor: ApocalypseTheme.primary
            ) {
                showLanguagePicker = true
            }

            Divider().padding(.leading, 56)

            SettingRow(
                icon: "person.circle",
                title: languageManager.localizedString("账号信息"),
                iconColor: .cyan
            ) {}

            Divider().padding(.leading, 56)

            SettingRow(
                icon: "bell.badge",
                title: languageManager.localizedString("通知设置"),
                iconColor: .orange
            ) {}

            Divider().padding(.leading, 56)

            SettingRow(
                icon: "lock.shield",
                title: languageManager.localizedString("隐私与安全"),
                iconColor: .blue
            ) {}

            Divider().padding(.leading, 56)

            SettingRow(
                icon: "info.circle",
                title: languageManager.localizedString("关于"),
                iconColor: .gray
            ) {}
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 退出登录按钮
    private var logoutButton: some View {
        Button(action: { showLogoutConfirm = true }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                Text(languageManager.localizedString("退出登录"))
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
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 带值的设置行组件
struct SettingRowWithValue: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
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
