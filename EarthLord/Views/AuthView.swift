//
//  AuthView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/12.
//

import SwiftUI

// MARK: - 认证页面
/// 处理用户登录、注册、找回密码的认证页面
struct AuthView: View {

    // MARK: - 状态

    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 当前选中的Tab（0: 登录, 1: 注册）
    @State private var selectedTab: Int = 0

    /// 计算实际应该显示的Tab（考虑注册流程状态）
    private var effectiveTab: Int {
        // 🔧 如果处于注册流程中，强制显示注册Tab
        if authManager.otpSent || authManager.otpVerified || authManager.needsPasswordSetup {
            return 1
        }
        return selectedTab
    }

    /// 是否显示忘记密码弹窗
    @State private var showForgotPassword: Bool = false

    /// Toast 消息
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

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            // 主内容
            ScrollView {
                VStack(spacing: 24) {
                    // Logo 区域
                    logoSection
                        .padding(.top, 60)

                    // Tab 切换
                    tabSelector
                        .padding(.horizontal, 24)

                    // 内容区域
                    // 🔧 使用 effectiveTab 而不是 selectedTab，确保注册流程中始终显示注册视图
                    if effectiveTab == 0 {
                        loginView
                            .onAppear {
                                print("📱 AuthView: 显示登录视图")
                                print("   selectedTab: \(selectedTab), effectiveTab: \(effectiveTab)")
                            }
                    } else {
                        registerView
                            .onAppear {
                                print("📱 AuthView: 显示注册视图")
                                print("   selectedTab: \(selectedTab), effectiveTab: \(effectiveTab)")
                                print("   otpSent: \(authManager.otpSent)")
                                print("   otpVerified: \(authManager.otpVerified)")
                                print("   needsPasswordSetup: \(authManager.needsPasswordSetup)")
                            }
                    }

                    // 分隔线
                    dividerSection
                        .padding(.top, 16)

                    // 第三方登录
                    thirdPartyLoginSection

                    Spacer(minLength: 40)
                }
            }

            // 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast 提示
            if let message = toastMessage {
                toastView(message: message)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.errorMessage) { _, newValue in
            if let error = newValue {
                showToast(error)
                authManager.clearError()
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            print("📱 AuthView: selectedTab 变化: \(oldValue) -> \(newValue), effectiveTab = \(effectiveTab)")
        }
        .onChange(of: effectiveTab) { oldValue, newValue in
            print("📱 AuthView: effectiveTab 变化: \(oldValue) -> \(newValue)")
        }
        .onAppear {
            print("📱 AuthView: 页面出现")
            print("   selectedTab: \(selectedTab)")
            print("   effectiveTab: \(effectiveTab)")
        }
    }

    // MARK: - 背景渐变
    private var backgroundGradient: some View {
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
    }

    // MARK: - Logo 区域
    private var logoSection: some View {
        VStack(spacing: 16) {
            // Logo
            ZStack {
                // 光晕效果
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0)
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                // Logo 背景
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
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 15)

                // 地球图标
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // 标题
            VStack(spacing: 4) {
                Text("地球新主")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("EARTH LORD")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .tracking(3)
            }
        }
    }

    // MARK: - Tab 选择器
    private var tabSelector: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            Button(action: {
                // 🔧 只有不在注册流程中才允许切换到登录Tab
                if !authManager.otpSent && !authManager.otpVerified && !authManager.needsPasswordSetup {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 0
                    }
                } else {
                    print("📱 TabSelector: 注册流程中，阻止切换到登录Tab")
                }
            }) {
                Text("登录")
                    .font(.system(size: 16, weight: effectiveTab == 0 ? .semibold : .regular))
                    .foregroundColor(effectiveTab == 0 ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(effectiveTab == 0 ? ApocalypseTheme.primary : Color.clear)
                                .frame(height: 2)
                        }
                    )
            }
            .disabled(authManager.otpSent || authManager.otpVerified || authManager.needsPasswordSetup)  // 🔧 注册流程中禁用登录Tab

            // 注册 Tab
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                }
            }) {
                Text("注册")
                    .font(.system(size: 16, weight: effectiveTab == 1 ? .semibold : .regular))
                    .foregroundColor(effectiveTab == 1 ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(effectiveTab == 1 ? ApocalypseTheme.primary : Color.clear)
                                .frame(height: 2)
                        }
                    )
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }

    // MARK: - 登录视图
    private var loginView: some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入框
            AuthTextField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword,
                isSecure: true
            )

            // 登录按钮
            AuthButton(title: "登录", isLoading: authManager.isLoading) {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)

            // 忘记密码链接
            Button(action: {
                resetEmail = loginEmail // 自动填充邮箱
                showForgotPassword = true
            }) {
                Text("忘记密码？")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 注册视图
    private var registerView: some View {
        VStack(spacing: 16) {
            // 根据状态显示不同步骤
            if authManager.otpVerified && authManager.needsPasswordSetup {
                // 第三步：设置密码
                registerStep3
                    .onAppear {
                        print("📱 UI: 显示注册第三步（设置密码）")
                        print("   otpVerified: \(authManager.otpVerified)")
                        print("   needsPasswordSetup: \(authManager.needsPasswordSetup)")
                        print("   isAuthenticated: \(authManager.isAuthenticated)")
                    }
            } else if authManager.otpSent {
                // 第二步：验证验证码
                registerStep2
                    .onAppear {
                        print("📱 UI: 显示注册第二步（验证验证码）")
                        print("   otpSent: \(authManager.otpSent)")
                        print("   otpVerified: \(authManager.otpVerified)")
                    }
            } else {
                // 第一步：输入邮箱
                registerStep1
                    .onAppear {
                        print("📱 UI: 显示注册第一步（输入邮箱）")
                    }
            }
        }
        .padding(.horizontal, 24)
        .onChange(of: authManager.otpVerified) { oldValue, newValue in
            print("📱 UI: otpVerified 变化: \(oldValue) -> \(newValue)")
        }
        .onChange(of: authManager.needsPasswordSetup) { oldValue, newValue in
            print("📱 UI: needsPasswordSetup 变化: \(oldValue) -> \(newValue)")
        }
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            print("📱 UI: isAuthenticated 变化: \(oldValue) -> \(newValue)")
        }
    }

    // MARK: - 注册第一步：输入邮箱
    private var registerStep1: some View {
        VStack(spacing: 16) {
            // 步骤指示
            StepIndicator(currentStep: 1, totalSteps: 3)

            Text("输入您的邮箱地址")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 邮箱输入框
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            // 发送验证码按钮
            AuthButton(title: "发送验证码", isLoading: authManager.isLoading) {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        startResendCountdown()
                    }
                }
            }
            .disabled(registerEmail.isEmpty || !isValidEmail(registerEmail))
        }
    }

    // MARK: - 注册第二步：验证码验证
    private var registerStep2: some View {
        VStack(spacing: 16) {
            // 步骤指示
            StepIndicator(currentStep: 2, totalSteps: 3)

            Text("验证码已发送至 \(registerEmail)")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            // 验证码输入框
            AuthTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $registerCode,
                keyboardType: .numberPad
            )

            // 验证按钮
            AuthButton(title: "验证", isLoading: authManager.isLoading) {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerCode)
                }
            }
            .disabled(registerCode.count != 6)

            // 重新发送
            HStack {
                if resendCountdown > 0 {
                    Text("\(resendCountdown)秒后可重新发送")
                        .font(.system(size: 14))
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
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }

            // 返回上一步
            Button(action: {
                authManager.resetOTPState()
                registerCode = ""
            }) {
                Text("返回上一步")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - 注册第三步：设置密码
    private var registerStep3: some View {
        VStack(spacing: 16) {
            // 步骤指示
            StepIndicator(currentStep: 3, totalSteps: 3)

            Text("设置您的登录密码")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 密码输入框
            AuthTextField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $registerPassword,
                isSecure: true
            )

            // 确认密码输入框
            AuthTextField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword,
                isSecure: true
            )

            // 密码不匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 完成注册按钮
            AuthButton(title: "完成注册", isLoading: authManager.isLoading) {
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
        HStack(spacing: 16) {
            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
                .lineLimit(1)
                .fixedSize()

            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 第三方登录
    private var thirdPartyLoginSection: some View {
        VStack(spacing: 12) {
            // Apple 登录按钮
            Button(action: {
                showToast("Apple 登录即将开放")
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20))
                    Text("通过 Apple 登录")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
            }

            // Google 登录按钮
            Button(action: {
                showToast("Google 登录即将开放")
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20))
                    Text("通过 Google 登录")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 忘记密码弹窗
    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 根据状态显示不同步骤
                        if resetOtpVerified {
                            // 第三步：设置新密码
                            resetStep3
                        } else if resetOtpSent {
                            // 第二步：验证验证码
                            resetStep2
                        } else {
                            // 第一步：输入邮箱
                            resetStep1
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }

                // 加载遮罩
                if authManager.isLoading {
                    loadingOverlay
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
        .presentationDetents([.medium, .large])
    }

    // MARK: - 找回密码第一步
    private var resetStep1: some View {
        VStack(spacing: 16) {
            StepIndicator(currentStep: 1, totalSteps: 3)

            Text("输入您注册时使用的邮箱")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            AuthButton(title: "发送验证码", isLoading: authManager.isLoading) {
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

    // MARK: - 找回密码第二步
    private var resetStep2: some View {
        VStack(spacing: 16) {
            StepIndicator(currentStep: 2, totalSteps: 3)

            Text("验证码已发送至 \(resetEmail)")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            AuthTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $resetCode,
                keyboardType: .numberPad
            )

            AuthButton(title: "验证", isLoading: authManager.isLoading) {
                Task {
                    await authManager.verifyResetOTP(email: resetEmail, code: resetCode)
                    if authManager.otpVerified {
                        resetOtpVerified = true
                    }
                }
            }
            .disabled(resetCode.count != 6)

            // 重新发送
            HStack {
                if resetResendCountdown > 0 {
                    Text("\(resetResendCountdown)秒后可重新发送")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Button(action: {
                        Task {
                            await authManager.sendResetOTP(email: resetEmail)
                            startResetResendCountdown()
                        }
                    }) {
                        Text("重新发送验证码")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
        }
    }

    // MARK: - 找回密码第三步
    private var resetStep3: some View {
        VStack(spacing: 16) {
            StepIndicator(currentStep: 3, totalSteps: 3)

            Text("设置您的新密码")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthTextField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $resetPassword,
                isSecure: true
            )

            AuthTextField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetConfirmPassword,
                isSecure: true
            )

            if !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            AuthButton(title: "重置密码", isLoading: authManager.isLoading) {
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

    // MARK: - 加载遮罩
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)

                Text("请稍候...")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Toast 视图
    private func toastView(message: String) -> some View {
        VStack {
            Spacer()

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: toastMessage)
    }

    // MARK: - 辅助方法

    /// 显示 Toast
    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            toastMessage = nil
        }
    }

    /// 验证邮箱格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// 开始注册重发倒计时
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

    /// 开始找回密码重发倒计时
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

    /// 重置找回密码状态
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

// MARK: - 自定义输入框组件
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    @State private var showPassword: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 24)

            // 输入框
            if isSecure && !showPassword {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .autocapitalization(.none)
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .textContentType(isSecure ? .password : .emailAddress)
            }

            // 密码显示/隐藏按钮
            if isSecure {
                Button(action: {
                    showPassword.toggle()
                }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 自定义按钮组件
struct AuthButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isEnabled ? ApocalypseTheme.primary : ApocalypseTheme.textMuted
            )
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

// MARK: - 步骤指示器
struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 8, height: 8)

                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .frame(width: 30, height: 2)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 预览
#Preview {
    AuthView()
}
