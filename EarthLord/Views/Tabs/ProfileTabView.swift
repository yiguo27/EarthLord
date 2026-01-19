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
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showLogoutConfirm = false
    @State private var showDeleteAccountSheet = false
    @State private var deleteConfirmText = ""
    @State private var showDeleteAccountAlert = false
    @State private var deleteAccountMessage = ""
    @State private var isDeleting = false
    @State private var showLanguagePicker = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 幸存者档案卡片
                    survivorProfileCard

                    // 数据统计卡片
                    statsCard

                    // 功能列表
                    functionsCard

                    // 退出登录按钮
                    logoutButton
                        .padding(.top, 8)

                    // 删除账户按钮
                    deleteAccountButton
                        .padding(.top, 8)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
            }
        }
        .confirmationDialog(languageManager.localizedString("确定要退出登录吗？"), isPresented: $showLogoutConfirm) {
            Button(languageManager.localizedString("退出登录"), role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
            Button(languageManager.localizedString("取消"), role: .cancel) {}
        } message: {
            Text(languageManager.localizedString("退出后需要重新登录"))
        }
        .sheet(isPresented: $showDeleteAccountSheet) {
            deleteAccountConfirmSheet
        }
        .alert(languageManager.localizedString("提示"), isPresented: $showDeleteAccountAlert) {
            Button(languageManager.localizedString("确定"), role: .cancel) {}
        } message: {
            Text(deleteAccountMessage)
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
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
                            // 图标
                            ZStack {
                                Circle()
                                    .fill(ApocalypseTheme.primary.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: language.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(ApocalypseTheme.primary)
                            }

                            // 语言名称
                            Text(language.displayName)
                                .font(.system(size: 16))
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Spacer()

                            // 选中标记
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
                        Divider()
                            .padding(.leading, 76)
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

    // MARK: - 删除账户按钮
    private var deleteAccountButton: some View {
        Button(action: {
            print("🗑️ ProfileTabView: 用户点击删除账户按钮")
            deleteConfirmText = ""
            showDeleteAccountSheet = true
        }) {
            HStack {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16))

                Text(languageManager.localizedString("删除账户"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(ApocalypseTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - 删除账户确认弹窗
    private var deleteAccountConfirmSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 警告图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.danger.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.danger)
                }
                .padding(.top, 20)

                // 警告文字
                VStack(spacing: 12) {
                    Text(languageManager.localizedString("删除账户"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(languageManager.localizedString("此操作不可撤销！\n您的所有数据将被永久删除，包括："))
                        .font(.system(size: 15))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(languageManager.localizedString("个人资料"), systemImage: "person.fill")
                        Label(languageManager.localizedString("领地数据"), systemImage: "flag.fill")
                        Label(languageManager.localizedString("游戏进度"), systemImage: "gamecontroller.fill")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
                }

                // 输入确认
                VStack(alignment: .leading, spacing: 8) {
                    Text(languageManager.localizedString("请输入 DELETE 以确认操作"))
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    TextField("DELETE", text: $deleteConfirmText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: deleteConfirmText) { _, newValue in
                            print("🗑️ ProfileTabView: 输入内容 = '\(newValue)', 长度 = \(newValue.count)")
                        }
                }
                .padding(.horizontal, 20)

                Spacer()

                // 按钮
                VStack(spacing: 12) {
                    let canDelete = deleteConfirmText.uppercased() == "DELETE" && !isDeleting

                    Button(action: {
                        print("🗑️ ProfileTabView: 用户点击确认删除按钮, canDelete = \(canDelete)")
                        if canDelete {
                            performDeleteAccount()
                        }
                    }) {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isDeleting ? languageManager.localizedString("删除中...") : languageManager.localizedString("确认删除"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canDelete ? ApocalypseTheme.danger : ApocalypseTheme.danger.opacity(0.3))
                        .cornerRadius(12)
                    }
                    .disabled(!canDelete)

                    Button(action: {
                        print("🗑️ ProfileTabView: 用户取消删除账户")
                        showDeleteAccountSheet = false
                    }) {
                        Text(languageManager.localizedString("取消"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .disabled(isDeleting)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(ApocalypseTheme.background)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 执行删除账户
    private func performDeleteAccount() {
        guard deleteConfirmText.uppercased() == "DELETE" else {
            print("🗑️ ProfileTabView: 确认文字不匹配 ('\(deleteConfirmText)')，取消删除")
            return
        }

        isDeleting = true
        print("🗑️ ProfileTabView: 开始执行删除账户操作")

        Task {
            let success = await authManager.deleteAccount()
            isDeleting = false
            showDeleteAccountSheet = false

            if success {
                print("🗑️ ProfileTabView: 账户删除成功")
                deleteAccountMessage = "账户已成功删除"
            } else {
                print("🗑️ ProfileTabView: 账户删除失败 - \(authManager.errorMessage ?? "未知错误")")
                deleteAccountMessage = authManager.errorMessage ?? "删除失败，请稍后重试"
            }
            showDeleteAccountAlert = true
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

                Text(languageManager.localizedString("幸存者档案"))
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
                    Text(authManager.currentUser?.email ?? languageManager.localizedString("未登录"))
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

                        Text(languageManager.localizedString("Lv.1 新手幸存者"))
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

                Text(languageManager.localizedString("生存数据"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 统计网格
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    StatItem(
                        icon: "flag.fill",
                        title: languageManager.localizedString("领地"),
                        value: "0",
                        color: ApocalypseTheme.primary
                    )

                    StatItem(
                        icon: "mappin.circle.fill",
                        title: languageManager.localizedString("资源点"),
                        value: "0",
                        color: .orange
                    )
                }

                HStack(spacing: 6) {
                    StatItem(
                        icon: "location.fill",
                        title: languageManager.localizedString("探索距离"),
                        value: "0 km",
                        color: .green
                    )

                    StatItem(
                        icon: "clock.fill",
                        title: languageManager.localizedString("生存天数"),
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
            // 语言设置
            ProfileFunctionRowWithValue(
                icon: "globe",
                title: languageManager.localizedString("语言"),
                value: languageManager.currentLanguage.displayName,
                iconColor: ApocalypseTheme.primary
            ) {
                showLanguagePicker = true
            }

            Divider()
                .padding(.leading, 56)

            ProfileFunctionRow(
                icon: "gearshape.fill",
                title: languageManager.localizedString("设置"),
                iconColor: .gray
            ) {
                // TODO: 跳转到设置页面
            }

            Divider()
                .padding(.leading, 56)

            ProfileFunctionRow(
                icon: "bell.badge.fill",
                title: languageManager.localizedString("通知"),
                iconColor: .orange
            ) {
                // TODO: 跳转到通知页面
            }

            Divider()
                .padding(.leading, 56)

            ProfileFunctionRow(
                icon: "questionmark.circle.fill",
                title: languageManager.localizedString("帮助"),
                iconColor: .blue
            ) {
                // TODO: 跳转到帮助页面
            }

            Divider()
                .padding(.leading, 56)

            ProfileFunctionRow(
                icon: "info.circle.fill",
                title: languageManager.localizedString("关于"),
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

// MARK: - 带值的功能行组件
private struct ProfileFunctionRowWithValue: View {
    let icon: String
    let title: String
    let value: String
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

                // 当前值
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

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
