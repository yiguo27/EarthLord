//
//  ModernAuthView.swift
//  EarthLord
//
//  现代化认证界面 - 基于设计最佳实践
//

import SwiftUI

struct ModernAuthView: View {
    // MARK: - 状态
    @ObservedObject private var authManager = AuthManager.shared
    @State private var selectedTab: Int = 0
    @State private var showForgotPassword: Bool = false
    @State private var toastMessage: String?

    // MARK: - 登录表单
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""

    // MARK: - 注册表单
    @State private var registerEmail: String = ""
    @State private var registerCode: String = ""
    @State private var registerPassword: String = ""
    @State private var registerConfirmPassword: String = ""

    // MARK: - 找回密码表单
    @State private var resetEmail: String = ""
    @State private var resetCode: String = ""
    @State private var resetPassword: String = ""
    @State private var resetConfirmPassword: String = ""
    @State private var resetOtpSent: Bool = false
    @State private var resetOtpVerified: Bool = false

    // MARK: - 倒计时
    @State private var resendCountdown: Int = 0
    @State private var resetResendCountdown: Int = 0

    // 计算实际应该显示的Tab
    private var effectiveTab: Int {
        if authManager.otpSent || authManager.otpVerified || authManager.needsPasswordSetup {
            return 1
        }
        return selectedTab
    }

    var body: some View {
        ZStack {
            // 背景渐变
            ModernAuthTheme.backgroundGradient
                .ignoresSafeArea()

            // 主内容
            ScrollView(showsIndicators: false) {
                VStack(spacing: ModernAuthTheme.spacing32) {
                    // Logo 区域
                    ModernLogoView()
                        .padding(.top, ModernAuthTheme.spacing48)

                    // 内容卡片
                    VStack(spacing: 0) {
                        // Tab 切换
                        tabSelector

                        // 内容区域
                        if effectiveTab == 0 {
                            loginView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        } else {
                            registerView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: ModernAuthTheme.radiusLarge)
                            .fill(ModernAuthTheme.cardGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernAuthTheme.radiusLarge)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, ModernAuthTheme.spacing24)

                    // 分隔线
                    dividerSection

                    // 第三方登录
                    thirdPartyLoginSection
                        .padding(.horizontal, ModernAuthTheme.spacing24)

                    Spacer(minLength: ModernAuthTheme.spacing40)
                }
            }

            // 加载遮罩
            if authManager.isLoading {
                ModernLoadingOverlay()
            }

            // Toast 提示
            if let message = toastMessage {
                ModernToast(message: message)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.errorMessage) { newValue in
            if let error = newValue {
                showToast(error)
                authManager.clearError()
            }
        }
    }

    // MARK: - Tab 选择器
    private var tabSelector: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            Button(action: {
                if !authManager.otpSent && !authManager.otpVerified && !authManager.needsPasswordSetup {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 0
                    }
                }
            }) {
                VStack(spacing: ModernAuthTheme.spacing8) {
                    Text("登录")
                        .font(effectiveTab == 0 ? ModernAuthTheme.bodySemibold() : ModernAuthTheme.body())
                        .foregroundColor(effectiveTab == 0 ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                    Rectangle()
                        .fill(effectiveTab == 0 ? ApocalypseTheme.primary : Color.clear)
                        .frame(height: 3)
                        .cornerRadius(1.5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ModernAuthTheme.spacing16)
                .contentShape(Rectangle())
            }
            .disabled(authManager.otpSent || authManager.otpVerified || authManager.needsPasswordSetup)

            // 注册 Tab
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 1
                }
            }) {
                VStack(spacing: ModernAuthTheme.spacing8) {
                    Text("注册")
                        .font(effectiveTab == 1 ? ModernAuthTheme.bodySemibold() : ModernAuthTheme.body())
                        .foregroundColor(effectiveTab == 1 ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                    Rectangle()
                        .fill(effectiveTab == 1 ? ApocalypseTheme.primary : Color.clear)
                        .frame(height: 3)
                        .cornerRadius(1.5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ModernAuthTheme.spacing16)
                .contentShape(Rectangle())
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: effectiveTab)
    }

    // MARK: - 登录视图
    private var loginView: some View {
        VStack(spacing: ModernAuthTheme.spacing20) {
            VStack(spacing: ModernAuthTheme.spacing16) {
                // 邮箱输入框
                ModernAuthTextField(
                    icon: "envelope.fill",
                    placeholder: "邮箱地址",
                    text: $loginEmail,
                    keyboardType: .emailAddress
                )

                // 密码输入框
                ModernAuthTextField(
                    icon: "lock.fill",
                    placeholder: "密码",
                    text: $loginPassword,
                    isSecure: true
                )
            }

            // 登录按钮
            ModernAuthButton(
                title: "登录",
                isLoading: authManager.isLoading,
                style: .primary
            ) {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)

            // 忘记密码链接
            Button(action: {
                resetEmail = loginEmail
                showForgotPassword = true
            }) {
                Text("忘记密码？")
                    .font(ModernAuthTheme.caption())
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(ModernAuthTheme.spacing24)
    }

    // MARK: - 注册视图
    private var registerView: some View {
        VStack(spacing: ModernAuthTheme.spacing20) {
            if authManager.otpVerified && authManager.needsPasswordSetup {
                registerStep3
            } else if authManager.otpSent {
                registerStep2
            } else {
                registerStep1
            }
        }
        .padding(ModernAuthTheme.spacing24)
    }

    // MARK: - 注册第一步：输入邮箱
    private var registerStep1: some View {
        VStack(spacing: ModernAuthTheme.spacing20) {
            // 步骤指示
            ModernStepIndicator(currentStep: 1, totalSteps: 3)

            // 提示文本
            Text("输入您的邮箱地址")
                .font(ModernAuthTheme.caption())
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 邮箱输入框
            ModernAuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            // 发送验证码按钮
            ModernAuthButton(
                title: "发送验证码",
                isLoading: authManager.isLoading,
                style: .primary
            ) {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        await MainActor.run {
                            startResendCountdown()
                        }
                    }
                }
            }
            .disabled(registerEmail.isEmpty || !isValidEmail(registerEmail))
        }
    }

    // MARK: - 注册第二步：验证码验证
    private var registerStep2: some View {
        VStack(spacing: ModernAuthTheme.spacing20) {
            // 步骤指示
            ModernStepIndicator(currentStep: 2, totalSteps: 3)

            // 提示文本
            VStack(spacing: ModernAuthTheme.spacing8) {
                Text("验证码已发送至")
                    .font(ModernAuthTheme.caption())
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(authManager.pendingEmail.isEmpty ? registerEmail : authManager.pendingEmail)
                    .font(ModernAuthTheme.captionMedium())
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 验证码输入框
            ModernAuthTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $registerCode,
                keyboardType: .numberPad
            )

            // 验证按钮
            ModernAuthButton(
                title: "验证",
                isLoading: authManager.isLoading,
                style: .primary
            ) {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerCode)
                }
            }
            .disabled(registerCode.count != 6)

            // 重新发送
            HStack(spacing: ModernAuthTheme.spacing8) {
                if resendCountdown > 0 {
                    Text("\(resendCountdown)秒后可重新发送")
                        .font(ModernAuthTheme.small())
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Button(action: {
                        Task {
                            await authManager.sendRegisterOTP(email: registerEmail)
                            if authManager.otpSent {
                                startResendCountdown()
                            }
                        }
                    }) {
                        Text("重新发送验证码")
                            .font(ModernAuthTheme.small())
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }

            // 返回上一步
            Button(action: {
                authManager.resetOTPState()
                registerCode = ""
                resendCountdown = 0
            }) {
                Text("返回上一步")
                    .font(ModernAuthTheme.caption())
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .onAppear {
            if resendCountdown == 0 {
                startResendCountdown()
            }
        }
    }

    // MARK: - 注册第三步：设置密码
    private var registerStep3: some View {
        VStack(spacing: ModernAuthTheme.spacing20) {
            // 步骤指示
            ModernStepIndicator(currentStep: 3, totalSteps: 3)

            // 提示文本
            Text("设置您的登录密码")
                .font(ModernAuthTheme.caption())
                .foregroundColor(ApocalypseTheme.textSecondary)

            VStack(spacing: ModernAuthTheme.spacing16) {
                // 密码输入框
                ModernAuthTextField(
                    icon: "lock.fill",
                    placeholder: "密码（至少6位）",
                    text: $registerPassword,
                    isSecure: true
                )

                // 确认密码输入框
                ModernAuthTextField(
                    icon: "lock.fill",
                    placeholder: "确认密码",
                    text: $registerConfirmPassword,
                    isSecure: true
                )

                // 密码不匹配提示
                if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                    HStack(spacing: ModernAuthTheme.spacing8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.danger)
                        Text("两次输入的密码不一致")
                            .font(ModernAuthTheme.small())
                            .foregroundColor(ApocalypseTheme.danger)
                        Spacer()
                    }
                }
            }

            // 完成注册按钮
            ModernAuthButton(
                title: "完成注册",
                isLoading: authManager.isLoading,
                style: .primary
            ) {
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                }
            }
            .disabled(
                registerPassword.count < 6 ||
                registerPassword != registerConfirmPassword
            )
        }
    }

    // MARK: - 分隔线
    private var dividerSection: some View {
        HStack(spacing: ModernAuthTheme.spacing16) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(ModernAuthTheme.small())
                .foregroundColor(ApocalypseTheme.textMuted)
                .fixedSize()

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
        .padding(.horizontal, ModernAuthTheme.spacing24)
    }

    // MARK: - 第三方登录
    private var thirdPartyLoginSection: some View {
        VStack(spacing: ModernAuthTheme.spacing12) {
            // Apple 登录按钮
            SocialLoginButton(
                icon: "apple.logo",
                title: "通过 Apple 登录",
                provider: .apple
            ) {
                showToast("Apple 登录即将开放")
            }

            // Google 登录按钮
            SocialLoginButton(
                icon: "g.circle.fill",
                title: "通过 Google 登录",
                provider: .google
            ) {
                Task {
                    await authManager.signInWithGoogle()
                }
            }
        }
    }

    // MARK: - 忘记密码弹窗
    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                ModernAuthTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: ModernAuthTheme.spacing24) {
                        if resetOtpVerified {
                            resetStep3
                        } else if resetOtpSent {
                            resetStep2
                        } else {
                            resetStep1
                        }
                    }
                    .padding(ModernAuthTheme.spacing24)
                }

                if authManager.isLoading {
                    ModernLoadingOverlay()
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        resetForgotPasswordState()
                        showForgotPassword = false
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 找回密码步骤
    private var resetStep1: some View {
        VStack(spacing: ModernAuthTheme.spacing20) {
            ModernStepIndicator(currentStep: 1, totalSteps: 3)

            Text("输入您注册时使用的邮箱")
                .font(ModernAuthTheme.caption())
                .foregroundColor(ApocalypseTheme.textSecondary)

            ModernAuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            ModernAuthButton(
                title: "发送验证码",
                isLoading: authManager.isLoading,
                style: .primary
            ) {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                    if authManager.otpSent {
                        resetOtpSent = true
                        startResetResendCountdown()
                    }
                }
            }
            .disabled(resetEmail.isEmpty || !isValidEmail(resetEmail))
        }
    }

    private var resetStep2: some View {
        VStack(spacing: ModernAuthTheme.spacing20) {
            ModernStepIndicator(currentStep: 2, totalSteps: 3)

            VStack(spacing: ModernAuthTheme.spacing8) {
                Text("验证码已发送至")
                    .font(ModernAuthTheme.caption())
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(resetEmail)
                    .font(ModernAuthTheme.captionMedium())
                    .foregroundColor(ApocalypseTheme.primary)
            }

            ModernAuthTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $resetCode,
                keyboardType: .numberPad
            )

            ModernAuthButton(
                title: "验证",
                isLoading: authManager.isLoading,
                style: .primary
            ) {
                Task {
                    await authManager.verifyResetOTP(email: resetEmail, code: resetCode)
                    if authManager.otpVerified {
                        resetOtpVerified = true
                    }
                }
            }
            .disabled(resetCode.count != 6)

            HStack {
                if resetResendCountdown > 0 {
                    Text("\(resetResendCountdown)秒后可重新发送")
                        .font(ModernAuthTheme.small())
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Button(action: {
                        Task {
                            await authManager.sendResetOTP(email: resetEmail)
                            startResetResendCountdown()
                        }
                    }) {
                        Text("重新发送验证码")
                            .font(ModernAuthTheme.small())
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
        }
    }

    private var resetStep3: some View {
        VStack(spacing: ModernAuthTheme.spacing20) {
            ModernStepIndicator(currentStep: 3, totalSteps: 3)

            Text("设置您的新密码")
                .font(ModernAuthTheme.caption())
                .foregroundColor(ApocalypseTheme.textSecondary)

            VStack(spacing: ModernAuthTheme.spacing16) {
                ModernAuthTextField(
                    icon: "lock.fill",
                    placeholder: "新密码（至少6位）",
                    text: $resetPassword,
                    isSecure: true
                )

                ModernAuthTextField(
                    icon: "lock.fill",
                    placeholder: "确认新密码",
                    text: $resetConfirmPassword,
                    isSecure: true
                )

                if !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                    HStack(spacing: ModernAuthTheme.spacing8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.danger)
                        Text("两次输入的密码不一致")
                            .font(ModernAuthTheme.small())
                            .foregroundColor(ApocalypseTheme.danger)
                        Spacer()
                    }
                }
            }

            ModernAuthButton(
                title: "重置密码",
                isLoading: authManager.isLoading,
                style: .primary
            ) {
                Task {
                    await authManager.resetPassword(newPassword: resetPassword)
                    if authManager.isAuthenticated {
                        resetForgotPasswordState()
                        showForgotPassword = false
                        showToast("密码重置成功")
                    }
                }
            }
            .disabled(
                resetPassword.count < 6 ||
                resetPassword != resetConfirmPassword
            )
        }
    }

    // MARK: - 辅助方法
    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            toastMessage = nil
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func startResendCountdown() {
        resendCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func startResetResendCountdown() {
        resetResendCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if resetResendCountdown > 0 {
                resetResendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func resetForgotPasswordState() {
        resetEmail = ""
        resetCode = ""
        resetPassword = ""
        resetConfirmPassword = ""
        resetOtpSent = false
        resetOtpVerified = false
        resetResendCountdown = 0
        authManager.resetOTPState()
    }
}

// MARK: - 预览
#Preview {
    ModernAuthView()
}
