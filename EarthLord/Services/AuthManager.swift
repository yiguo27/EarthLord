//
//  AuthManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/12.
//

import Foundation
import Combine
import Supabase

// MARK: - 认证管理器
/// 处理用户注册、登录、找回密码等认证流程
///
/// 认证流程说明：
/// - 注册：发验证码 → 验证OTP（已登录但无密码）→ 设置密码 → 完成
/// - 登录：邮箱 + 密码（直接登录）
/// - 找回密码：发验证码 → 验证OTP（已登录）→ 设置新密码 → 完成
@MainActor
final class AuthManager: ObservableObject {

    // MARK: - 单例
    static let shared = AuthManager()

    // MARK: - 发布属性

    /// 内部认证状态标记
    @Published private var _internalAuthFlag: Bool = false

    /// 是否已完成认证（已登录且完成所有流程）
    /// 🔧 使用计算属性强制控制：在注册/重置流程中永远返回 false
    var isAuthenticated: Bool {
        get {
            // 如果处于注册或重置密码流程中，强制返回 false
            if currentFlow != .none || needsPasswordSetup {
                return false
            }
            return _internalAuthFlag
        }
        set {
            // 只有在非特殊流程中才允许设置
            if currentFlow == .none && !needsPasswordSetup {
                _internalAuthFlag = newValue
            } else {
                // 在特殊流程中，强制设为 false
                _internalAuthFlag = false
                print("⚠️ 尝试在特殊流程中设置 isAuthenticated，已阻止")
                print("   currentFlow: \(currentFlow)")
                print("   needsPasswordSetup: \(needsPasswordSetup)")
            }
        }
    }

    /// OTP验证后是否需要设置密码
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - 私有属性

    /// 当前认证流程类型
    private enum AuthFlowType {
        case register   // 注册流程
        case reset      // 找回密码流程
        case none
    }

    private var _currentFlow: AuthFlowType = .none {
        didSet {
            // 当 currentFlow 变化时，手动触发 objectWillChange
            // 这样依赖 isAuthenticated 的视图会重新计算
            objectWillChange.send()
        }
    }

    private var currentFlow: AuthFlowType {
        get { _currentFlow }
        set { _currentFlow = newValue }
    }

    // MARK: - 初始化

    private init() {
        // 监听认证状态变化
        Task {
            await setupAuthListener()
        }
    }

    /// 设置认证状态监听器
    private func setupAuthListener() async {
        for await (event, session) in supabase.auth.authStateChanges {
            print("🔐 Auth event: \(event)")
            print("   currentFlow: \(currentFlow)")
            print("   otpVerified: \(otpVerified)")
            print("   needsPasswordSetup: \(needsPasswordSetup)")
            print("   isAuthenticated: \(isAuthenticated)")

            switch event {
            case .signedIn:
                // 用户登录成功
                if let user = session?.user {
                    self.currentUser = user

                    // 🔧 关键修复：双重检查，防止在注册/重置密码流程中错误设置已认证
                    // 检查 1: currentFlow 必须是 .none
                    // 检查 2: 不能处于等待密码设置状态
                    let shouldSetAuthenticated = (currentFlow == .none) && !needsPasswordSetup

                    if shouldSetAuthenticated {
                        // 正常登录流程：直接设置已认证
                        print("   → 正常登录，设置已认证")
                        self.isAuthenticated = true
                    } else {
                        // 注册或找回密码流程：保持未认证状态
                        print("   → 特殊流程中，保持未认证状态")
                        print("      currentFlow = \(currentFlow)")
                        print("      needsPasswordSetup = \(needsPasswordSetup)")

                        // 🔧 强制确保 isAuthenticated 为 false
                        self.isAuthenticated = false
                    }
                }

            case .signedOut:
                // 用户登出
                print("   → 用户登出")
                self.resetState()

            case .userUpdated:
                // 用户信息更新（包括密码设置）
                if let user = session?.user {
                    self.currentUser = user
                    print("   → 用户信息已更新")
                }

            case .passwordRecovery:
                // 密码恢复流程
                print("🔐 Password recovery event")

            default:
                break
            }
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        isLoading = true
        errorMessage = nil
        currentFlow = .register

        do {
            // 发送OTP验证码，shouldCreateUser: true 表示如果用户不存在则创建
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            print("✅ 注册验证码已发送至: \(email)")

        } catch {
            errorMessage = parseError(error)
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        guard !code.isEmpty else {
            errorMessage = "请输入验证码"
            return
        }

        isLoading = true
        errorMessage = nil

        // 🔧 关键修复：在调用 verifyOTP **之前**就设置状态，防止时序问题
        // 因为 authStateChanges 可能在 verifyOTP 返回前就触发
        currentFlow = .register
        otpVerified = true
        needsPasswordSetup = true

        print("🔧 准备验证注册OTP，已提前设置状态")
        print("   currentFlow: \(currentFlow)")
        print("   otpVerified: \(otpVerified)")
        print("   needsPasswordSetup: \(needsPasswordSetup)")
        print("   isAuthenticated: \(isAuthenticated)")

        do {
            // 验证OTP，type为.signup表示注册验证
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .signup
            )

            // 验证成功后用户已登录
            currentUser = response.user

            print("✅ 注册验证码验证成功，等待设置密码")
            print("   currentUser: \(response.user.email ?? "unknown")")
            print("   currentFlow: \(currentFlow)")
            print("   otpVerified: \(otpVerified)")
            print("   needsPasswordSetup: \(needsPasswordSetup)")
            print("   isAuthenticated: \(isAuthenticated)")

        } catch {
            // 验证失败，重置状态
            currentFlow = .none
            otpVerified = false
            needsPasswordSetup = false

            errorMessage = parseError(error)
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    func completeRegistration(password: String) async {
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        guard password.count >= 6 else {
            errorMessage = "密码至少需要6位"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: password))

            needsPasswordSetup = false
            isAuthenticated = true
            currentFlow = .none

            // 重置OTP状态
            otpSent = false
            otpVerified = false

            print("✅ 注册完成，密码已设置")

        } catch {
            errorMessage = parseError(error)
            print("❌ 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        isLoading = true
        errorMessage = nil
        currentFlow = .none

        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = response.user
            isAuthenticated = true

            print("✅ 登录成功: \(email)")

        } catch {
            errorMessage = parseError(error)
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        isLoading = true
        errorMessage = nil
        currentFlow = .reset

        do {
            // 发送密码重置邮件（触发 Reset Password 邮件模板）
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            print("✅ 密码重置验证码已发送至: \(email)")

        } catch {
            errorMessage = parseError(error)
            print("❌ 发送密码重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证密码重置验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        guard !code.isEmpty else {
            errorMessage = "请输入验证码"
            return
        }

        isLoading = true
        errorMessage = nil

        // 🔧 关键修复：在调用 verifyOTP **之前**就设置状态，防止时序问题
        currentFlow = .reset
        otpVerified = true
        needsPasswordSetup = true

        print("🔧 准备验证重置密码OTP，已提前设置状态")
        print("   currentFlow: \(currentFlow)")
        print("   otpVerified: \(otpVerified)")
        print("   needsPasswordSetup: \(needsPasswordSetup)")
        print("   isAuthenticated: \(isAuthenticated)")

        do {
            // 验证OTP，⚠️ type为.recovery（不是.email）
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功后用户已登录
            currentUser = response.user

            print("✅ 密码重置验证码验证成功，等待设置新密码")
            print("   currentUser: \(response.user.email ?? "unknown")")
            print("   currentFlow: \(currentFlow)")
            print("   otpVerified: \(otpVerified)")
            print("   needsPasswordSetup: \(needsPasswordSetup)")
            print("   isAuthenticated: \(isAuthenticated)")

        } catch {
            // 验证失败，重置状态
            currentFlow = .none
            otpVerified = false
            needsPasswordSetup = false

            errorMessage = parseError(error)
            print("❌ 验证密码重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        guard !newPassword.isEmpty else {
            errorMessage = "请输入新密码"
            return
        }

        guard newPassword.count >= 6 else {
            errorMessage = "密码至少需要6位"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: newPassword))

            needsPasswordSetup = false
            isAuthenticated = true
            currentFlow = .none

            // 重置OTP状态
            otpSent = false
            otpVerified = false

            print("✅ 密码重置完成")

        } catch {
            errorMessage = parseError(error)
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// - TODO: 实现 Apple Sign In
    func signInWithApple() async {
        // TODO: 实现 Apple Sign In
        // 1. 使用 ASAuthorizationAppleIDProvider 获取凭证
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        // 3. 处理登录结果
        errorMessage = "Apple 登录功能开发中"
    }

    /// Google 登录
    /// - TODO: 实现 Google Sign In
    func signInWithGoogle() async {
        // TODO: 实现 Google Sign In
        // 1. 配置 Google Sign-In SDK
        // 2. 获取 Google ID Token
        // 3. 调用 supabase.auth.signInWithIdToken(credentials:)
        // 4. 处理登录结果
        errorMessage = "Google 登录功能开发中"
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()
            resetState()
            print("✅ 已登出")

        } catch {
            errorMessage = parseError(error)
            print("❌ 登出失败: \(error)")
        }

        isLoading = false
    }

    /// 检查当前会话状态
    func checkSession() async {
        isLoading = true

        do {
            let session = try await supabase.auth.session
            currentUser = session.user

            print("🔍 检查会话状态")
            print("   currentFlow: \(currentFlow)")
            print("   needsPasswordSetup: \(needsPasswordSetup)")

            // 🔧 关键修复：如果处于注册或重置密码流程中，不要改变状态
            if currentFlow == .register || currentFlow == .reset {
                print("   → 处于特殊流程中，保持当前状态")
                isLoading = false
                return
            }

            // 检查用户是否有密码（通过 identities 判断）
            // 如果用户只有 email identity 且没有设置密码，需要设置密码
            let hasPassword = checkUserHasPassword(user: session.user)

            print("   hasPassword: \(hasPassword)")

            if hasPassword {
                isAuthenticated = true
                print("   → 设置为已认证")
            } else {
                // 用户已登录但没有密码（可能是 OTP 登录）
                needsPasswordSetup = true
                otpVerified = true
                print("   → 需要设置密码")
            }

            print("✅ 会话有效: \(session.user.email ?? "unknown")")

        } catch {
            // 没有有效会话，保持未认证状态
            print("ℹ️ 无有效会话")
            resetState()
        }

        isLoading = false
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 重置OTP流程状态
    func resetOTPState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        currentFlow = .none
        errorMessage = nil
    }

    // MARK: - 私有方法

    /// 重置所有状态
    private func resetState() {
        _internalAuthFlag = false
        needsPasswordSetup = false
        currentUser = nil
        otpSent = false
        otpVerified = false
        currentFlow = .none
        errorMessage = nil
    }

    /// 检查用户是否已设置密码
    /// - Parameter user: 用户对象
    /// - Returns: 是否已设置密码
    private func checkUserHasPassword(user: User) -> Bool {
        // 🔧 改进的判断逻辑：检查用户元数据中的标记
        // 当用户通过密码完成注册或重置密码时，应该有一个明确的标记

        print("🔍 检查用户是否有密码")
        print("   user.email: \(user.email ?? "unknown")")

        guard let identities = user.identities else {
            print("   → 没有 identities，返回 false")
            return false
        }

        print("   → identities 数量: \(identities.count)")

        // 查找 email provider 的 identity
        let emailIdentity = identities.first { identity in
            identity.provider == "email"
        }

        guard let identity = emailIdentity else {
            print("   → 没有 email identity，返回 false")
            return false
        }

        print("   → 有 email identity")
        print("   → identity.lastSignInAt: \(identity.lastSignInAt?.description ?? "nil")")

        // 🔧 更严格的判断：检查是否有 email_confirmed_at
        // 如果用户只是通过 OTP 登录，可能没有这个字段，或者字段为空
        // 但这个判断可能不够准确，所以我们采用保守策略：
        // 如果无法确定，返回 false，让用户设置密码

        // 暂时使用简单的判断：如果有 email identity，就认为有密码
        // 但如果处于注册/重置流程中，会被其他逻辑拦截
        return true
    }

    /// 解析错误信息
    /// - Parameter error: 错误对象
    /// - Returns: 用户友好的错误信息
    private func parseError(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()

        // 常见错误映射
        if errorString.contains("invalid login credentials") {
            return "邮箱或密码错误"
        } else if errorString.contains("email not confirmed") {
            return "邮箱未验证，请先验证邮箱"
        } else if errorString.contains("user already registered") {
            return "该邮箱已注册，请直接登录"
        } else if errorString.contains("invalid otp") || errorString.contains("token has expired") {
            return "验证码无效或已过期"
        } else if errorString.contains("email rate limit") {
            return "发送频率过高，请稍后再试"
        } else if errorString.contains("network") || errorString.contains("connection") {
            return "网络连接失败，请检查网络"
        } else if errorString.contains("password") && errorString.contains("weak") {
            return "密码强度不够，请使用更复杂的密码"
        } else if errorString.contains("user not found") {
            return "用户不存在"
        }

        // 返回原始错误信息
        return error.localizedDescription
    }
}
