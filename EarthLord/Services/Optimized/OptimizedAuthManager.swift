//
//  OptimizedAuthManager.swift
//  EarthLord
//
//  优化版：认证管理器 - 缓存 userId，避免重复查询
//

import Foundation
import Combine
import Supabase
import GoogleSignIn
import UIKit

@MainActor
final class OptimizedAuthManager: ObservableObject {
    static let shared = OptimizedAuthManager()

    // MARK: - Published 属性

    @Published private var _internalAuthFlag: Bool = false
    @Published var needsPasswordSetup: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var otpSent: Bool = false
    @Published var otpVerified: Bool = false
    @Published var pendingEmail: String = ""

    // ✅ 缓存 userId（避免重复查询）
    private(set) var cachedUserId: String?

    var isAuthenticated: Bool {
        get {
            if currentFlow != .none || needsPasswordSetup { return false }
            return _internalAuthFlag
        }
        set {
            if currentFlow == .none && !needsPasswordSetup {
                _internalAuthFlag = newValue
            } else {
                _internalAuthFlag = false
            }
        }
    }

    // MARK: - 私有属性

    private enum AuthFlowType {
        case register, reset, none
    }

    private var currentFlow: AuthFlowType = .none

    // MARK: - 初始化

    private init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com"
        )

        Task { await setupAuthListener() }
    }

    // MARK: - 公共方法

    /// ✅ 获取 userId（优先使用缓存）
    func getUserId() async throws -> String {
        // 1️⃣ 优先使用缓存
        if let cachedId = cachedUserId {
            return cachedId
        }

        // 2️⃣ 缓存未命中，从 session 获取
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        // 3️⃣ 更新缓存
        cachedUserId = userId
        return userId
    }

    /// ✅ 并行验证 OTP
    func verifyRegisterOTP(email: String, code: String) async {
        guard !code.isEmpty else { errorMessage = "请输入验证码"; return }

        let emailToVerify = email.isEmpty ? pendingEmail : email
        guard !emailToVerify.isEmpty else { errorMessage = "邮箱地址丢失，请重新开始"; return }

        isLoading = true
        errorMessage = nil
        currentFlow = .register

        print("🔐 OptimizedAuthManager: 开始并行验证OTP")

        // ✅ 使用 TaskGroup 并行尝试三种类型
        await withTaskGroup(of: (AuthResponse, OTPType)?.self) { group in
            // 同时启动三个验证任务
            group.addTask {
                try? (
                    await supabase.auth.verifyOTP(email: emailToVerify, token: code, type: .magiclink),
                    .magiclink
                )
            }
            group.addTask {
                try? (
                    await supabase.auth.verifyOTP(email: emailToVerify, token: code, type: .email),
                    .email
                )
            }
            group.addTask {
                try? (
                    await supabase.auth.verifyOTP(email: emailToVerify, token: code, type: .signup),
                    .signup
                )
            }

            // 等待第一个成功的结果
            for await result in group {
                if let (response, type) = result {
                    print("🔐 OptimizedAuthManager: ✅ OTP验证成功 (类型: \(type))")

                    // ✅ 缓存 userId
                    self.cachedUserId = response.user.id.uuidString

                    self.currentUser = response.user
                    self.otpVerified = true
                    self.needsPasswordSetup = true

                    // 取消其他任务
                    group.cancelAll()
                    break
                }
            }
        }

        if !otpVerified {
            print("🔐 OptimizedAuthManager: ❌ 所有OTP类型验证失败")
            errorMessage = "验证码错误或已过期"
            currentFlow = .none
        }

        isLoading = false
    }

    /// 登录
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        currentFlow = .none

        do {
            let response = try await supabase.auth.signIn(email: email, password: password)

            // ✅ 缓存 userId
            cachedUserId = response.user.id.uuidString

            currentUser = response.user
            isAuthenticated = true
        } catch {
            errorMessage = parseError(error)
        }

        isLoading = false
    }

    /// 完成注册
    func completeRegistration(password: String) async {
        guard !password.isEmpty else { errorMessage = "请输入密码"; return }
        guard password.count >= 6 else { errorMessage = "密码至少需要6位"; return }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.update(user: UserAttributes(password: password))

            needsPasswordSetup = false
            isAuthenticated = true
            currentFlow = .none
            otpSent = false
            otpVerified = false
        } catch {
            errorMessage = parseError(error)
        }

        isLoading = false
    }

    /// Google 登录
    func signInWithGoogle() async {
        print("🔐 OptimizedAuthManager: 开始 Google 登录")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "无法初始化登录，请重试"
            return
        }

        isLoading = true
        errorMessage = nil
        currentFlow = .none

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google 登录失败：无法获取认证信息"
                isLoading = false
                return
            }

            let response = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )

            // ✅ 缓存 userId
            cachedUserId = response.user.id.uuidString

            currentUser = response.user
            isAuthenticated = true
            isLoading = false
        } catch {
            errorMessage = parseError(error)
            isLoading = false
        }
    }

    /// 检查会话
    func checkSession() async {
        isLoading = true

        do {
            let session = try await supabase.auth.session

            // ✅ 缓存 userId
            cachedUserId = session.user.id.uuidString

            currentUser = session.user

            if currentFlow != .register && currentFlow != .reset {
                isAuthenticated = true
            }
        } catch {
            resetState()
        }

        isLoading = false
    }

    /// 登出
    func signOut() async {
        try? await supabase.auth.signOut()

        // ✅ 清除缓存
        cachedUserId = nil

        resetState()
    }

    /// 删除账户
    func deleteAccount() async -> Bool {
        print("🗑️ OptimizedAuthManager: 开始删除账户")
        isLoading = true
        errorMessage = nil

        do {
            // ✅ 优先使用缓存的 userId
            let userId = try await getUserId()
            print("🗑️ OptimizedAuthManager: 使用缓存的 userId: \(userId)")

            let session = try await supabase.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: "https://hrtdgvplerzybnodjqmk.supabase.co/functions/v1/delete-account") else {
                errorMessage = "无效的请求地址"
                isLoading = false
                return false
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhydGRndnBsZXJ6eWJub2RqcW1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5MzU1NjksImV4cCI6MjA4MzUxMTU2OX0.Zgof7wvEDEHJUOxgJO3g3Aur-4XX9TcQGkVvRhPQ1Mk", forHTTPHeaderField: "apikey")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "无效的服务器响应"
                isLoading = false
                return false
            }

            if httpResponse.statusCode == 200 {
                print("🗑️ OptimizedAuthManager: ✅ 账户删除成功")
                resetState()
                isLoading = false
                return true
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    errorMessage = error
                } else {
                    errorMessage = "删除账户失败，请稍后重试"
                }
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - 其他方法（与原版相同）

    func sendRegisterOTP(email: String) async {
        guard !email.isEmpty else { errorMessage = "请输入邮箱地址"; return }
        isLoading = true
        errorMessage = nil
        currentFlow = .register
        pendingEmail = email

        do {
            try await supabase.auth.signInWithOTP(email: email, shouldCreateUser: true)
            otpSent = true
        } catch {
            errorMessage = parseError(error)
        }

        isLoading = false
    }

    func sendResetOTP(email: String) async {
        guard !email.isEmpty else { errorMessage = "请输入邮箱地址"; return }
        isLoading = true
        errorMessage = nil
        currentFlow = .reset

        do {
            try await supabase.auth.resetPasswordForEmail(email)
            otpSent = true
        } catch {
            errorMessage = parseError(error)
        }

        isLoading = false
    }

    func verifyResetOTP(email: String, code: String) async {
        guard !code.isEmpty else { errorMessage = "请输入验证码"; return }
        isLoading = true
        errorMessage = nil
        currentFlow = .reset

        do {
            let response = try await supabase.auth.verifyOTP(email: email, token: code, type: .recovery)

            // ✅ 缓存 userId
            cachedUserId = response.user.id.uuidString

            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true
        } catch {
            currentFlow = .none
            otpVerified = false
            needsPasswordSetup = false
            errorMessage = parseError(error)
        }

        isLoading = false
    }

    func resetPassword(newPassword: String) async {
        guard !newPassword.isEmpty else { errorMessage = "请输入新密码"; return }
        guard newPassword.count >= 6 else { errorMessage = "密码至少需要6位"; return }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))

            needsPasswordSetup = false
            isAuthenticated = true
            currentFlow = .none
            otpSent = false
            otpVerified = false
        } catch {
            errorMessage = parseError(error)
        }

        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }

    func resetOTPState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        currentFlow = .none
        errorMessage = nil
        pendingEmail = ""
    }

    // MARK: - 私有方法

    private func setupAuthListener() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let user = session?.user {
                    // ✅ 缓存 userId
                    self.cachedUserId = user.id.uuidString

                    self.currentUser = user

                    if currentFlow != .register && currentFlow != .reset {
                        let shouldSetAuthenticated = !needsPasswordSetup
                        self.isAuthenticated = shouldSetAuthenticated
                    }
                }
            case .signedOut:
                self.resetState()
            case .userUpdated:
                if let user = session?.user {
                    // ✅ 缓存 userId
                    self.cachedUserId = user.id.uuidString
                    self.currentUser = user
                }
            default:
                break
            }
        }
    }

    private func resetState() {
        _internalAuthFlag = false
        needsPasswordSetup = false
        currentUser = nil
        otpSent = false
        otpVerified = false
        currentFlow = .none
        errorMessage = nil
        pendingEmail = ""

        // ✅ 清除缓存
        cachedUserId = nil
    }

    private func parseError(_ error: Error) -> String {
        return error.localizedDescription
    }
}

// MARK: - OTPType 枚举

private enum OTPType {
    case magiclink
    case email
    case signup
}
