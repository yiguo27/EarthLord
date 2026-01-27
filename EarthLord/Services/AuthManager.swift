//
//  AuthManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/12.
//

import Foundation
import Combine
import Supabase
import GoogleSignIn
import UIKit

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    @Published private var _internalAuthFlag: Bool = false

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

    @Published var needsPasswordSetup: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var otpSent: Bool = false
    @Published var otpVerified: Bool = false
    @Published var pendingEmail: String = ""  // 🔧 存储待验证的邮箱

    private enum AuthFlowType {
        case register, reset, none
    }

    private var _currentFlow: AuthFlowType = .none {
        didSet { objectWillChange.send() }
    }

    private var currentFlow: AuthFlowType {
        get { _currentFlow }
        set { _currentFlow = newValue }
    }

    private init() {
        // 配置 Google Sign-In
        // ⚠️ 重要：请将下面的 YOUR_IOS_CLIENT_ID 替换为你在 Google Cloud Console 创建的 iOS 客户端 ID
        // 参考 GOOGLE_SIGN_IN_SETUP.md 文件获取详细配置说明
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com"
        )

        Task { await setupAuthListener() }
    }

    private func setupAuthListener() async {
        for await (event, session) in supabase.auth.authStateChanges {
            print("🔔 AuthListener: 收到事件 \(event)")
            print("   当前状态: currentFlow=\(currentFlow), otpVerified=\(otpVerified), needsPasswordSetup=\(needsPasswordSetup)")
            switch event {
            case .signedIn:
                if let user = session?.user {
                    print("🔔 AuthListener: signedIn - user=\(user.email ?? "nil")")
                    self.currentUser = user
                    // 🔧 关键：如果正在注册或重置密码流程中，不要改变认证状态
                    if currentFlow == .register || currentFlow == .reset {
                        print("🔔 AuthListener: 在注册/重置流程中，保持当前状态")
                    } else {
                        let shouldSetAuthenticated = !needsPasswordSetup
                        print("🔔 AuthListener: 设置 isAuthenticated = \(shouldSetAuthenticated)")
                        self.isAuthenticated = shouldSetAuthenticated
                    }
                }
            case .signedOut:
                print("🔔 AuthListener: signedOut - 重置状态")
                self.resetState()
            case .userUpdated:
                if let user = session?.user {
                    print("🔔 AuthListener: userUpdated - user=\(user.email ?? "nil")")
                    self.currentUser = user
                }
            default:
                print("🔔 AuthListener: 其他事件 \(event)")
            }
            print("🔔 AuthListener: 事件处理完成，状态: otpVerified=\(otpVerified), needsPasswordSetup=\(needsPasswordSetup), isAuthenticated=\(isAuthenticated)")
        }
    }

    func sendRegisterOTP(email: String) async {
        guard !email.isEmpty else { errorMessage = "请输入邮箱地址"; return }
        isLoading = true
        errorMessage = nil
        currentFlow = .register
        pendingEmail = email  // 🔧 保存邮箱
        do {
            try await supabase.auth.signInWithOTP(email: email, shouldCreateUser: true)
            otpSent = true
            print("🔐 AuthManager: OTP已发送到 \(pendingEmail)")
        } catch {
            errorMessage = parseError(error)
        }
        isLoading = false
    }

    func verifyRegisterOTP(email: String, code: String) async {
        guard !code.isEmpty else { errorMessage = "请输入验证码"; return }
        // 🔧 使用传入的email，如果为空则使用保存的pendingEmail
        let emailToVerify = email.isEmpty ? pendingEmail : email
        guard !emailToVerify.isEmpty else { errorMessage = "邮箱地址丢失，请重新开始"; return }

        isLoading = true
        errorMessage = nil
        currentFlow = .register
        print("🔐 AuthManager: 开始验证OTP, email=\(emailToVerify), code=\(code)")

        // 先尝试 magiclink 类型
        do {
            print("🔐 AuthManager: 尝试 magiclink 类型")
            let response = try await supabase.auth.verifyOTP(email: emailToVerify, token: code, type: .magiclink)
            print("🔐 AuthManager: OTP验证成功! (magiclink)")
            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true
            isLoading = false
            return
        } catch {
            print("🔐 AuthManager: magiclink 失败: \(error.localizedDescription)")
        }

        // 再尝试 email 类型
        do {
            print("🔐 AuthManager: 尝试 email 类型")
            let response = try await supabase.auth.verifyOTP(email: emailToVerify, token: code, type: .email)
            print("🔐 AuthManager: OTP验证成功! (email)")
            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true
            isLoading = false
            return
        } catch {
            print("🔐 AuthManager: email 失败: \(error.localizedDescription)")
        }

        // 最后尝试 signup 类型
        do {
            print("🔐 AuthManager: 尝试 signup 类型")
            let response = try await supabase.auth.verifyOTP(email: emailToVerify, token: code, type: .signup)
            print("🔐 AuthManager: OTP验证成功! (signup)")
            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true
            isLoading = false
            return
        } catch {
            print("🔐 AuthManager: signup 失败: \(error.localizedDescription)")
            errorMessage = parseError(error)
        }

        // 所有类型都失败了
        print("🔐 AuthManager: 所有OTP类型都验证失败!")
        currentFlow = .none
        otpVerified = false
        needsPasswordSetup = false
        isLoading = false
    }

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

    // MARK: - 找回密码

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

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        currentFlow = .none
        do {
            let response = try await supabase.auth.signIn(email: email, password: password)
            currentUser = response.user
            isAuthenticated = true
        } catch {
            errorMessage = parseError(error)
        }
        isLoading = false
    }

    // MARK: - Google 登录

    /// Google 登录
    func signInWithGoogle() async {
        print("🔐 AuthManager: 开始 Google 登录流程")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("🔐 AuthManager: ❌ 无法获取根视图控制器")
            await MainActor.run {
                errorMessage = "无法初始化登录，请重试"
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
            currentFlow = .none
        }

        do {
            // 第一步：通过 Google Sign-In SDK 获取 ID Token
            print("🔐 AuthManager: 正在调用 Google Sign-In SDK...")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                print("🔐 AuthManager: ❌ 无法获取 Google ID Token")
                await MainActor.run {
                    errorMessage = "Google 登录失败：无法获取认证信息"
                    isLoading = false
                }
                return
            }

            print("🔐 AuthManager: ✅ 成功获取 Google ID Token")

            // 第二步：使用 ID Token 通过 Supabase 登录
            print("🔐 AuthManager: 正在通过 Supabase 登录...")
            let response = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )

            print("🔐 AuthManager: ✅ Google 登录成功")
            await MainActor.run {
                currentUser = response.user
                isAuthenticated = true
                isLoading = false
            }
        } catch {
            print("🔐 AuthManager: ❌ Google 登录失败: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = parseError(error)
                isLoading = false
            }
        }
    }

    func checkSession() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            if currentFlow == .register || currentFlow == .reset {
                isLoading = false
                return
            }
            isAuthenticated = true
        } catch {
            resetState()
        }
        isLoading = false
    }

    func clearError() { errorMessage = nil }

    func resetOTPState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        currentFlow = .none
        errorMessage = nil
        pendingEmail = ""  // 🔧 清空待验证邮箱
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        resetState()
    }

    // MARK: - 删除账户

    func deleteAccount() async -> Bool {
        print("🗑️ AuthManager: 开始删除账户流程")
        isLoading = true
        errorMessage = nil

        do {
            // 获取当前会话的访问令牌
            print("🗑️ AuthManager: 正在获取用户会话...")
            let session = try await supabase.auth.session
            let accessToken = session.accessToken
            print("🗑️ AuthManager: 成功获取访问令牌")

            // 调用边缘函数删除账户
            guard let url = URL(string: "https://hrtdgvplerzybnodjqmk.supabase.co/functions/v1/delete-account") else {
                print("🗑️ AuthManager: 错误 - 无效的请求地址")
                errorMessage = "无效的请求地址"
                isLoading = false
                return false
            }

            print("🗑️ AuthManager: 正在调用删除账户边缘函数...")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // 添加 Supabase anon key 用于通过边缘函数的 JWT 验证
            request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhydGRndnBsZXJ6eWJub2RqcW1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5MzU1NjksImV4cCI6MjA4MzUxMTU2OX0.Zgof7wvEDEHJUOxgJO3g3Aur-4XX9TcQGkVvRhPQ1Mk", forHTTPHeaderField: "apikey")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("🗑️ AuthManager: 错误 - 无效的服务器响应")
                errorMessage = "无效的服务器响应"
                isLoading = false
                return false
            }

            print("🗑️ AuthManager: 服务器响应状态码: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 200 {
                print("🗑️ AuthManager: ✅ 账户删除成功，正在清理本地状态...")
                resetState()
                isLoading = false
                print("🗑️ AuthManager: ✅ 删除流程完成")
                return true
            } else {
                // 解析错误信息
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    print("🗑️ AuthManager: ❌ 服务器返回错误: \(error)")
                    errorMessage = error
                } else {
                    print("🗑️ AuthManager: ❌ 删除失败，状态码: \(httpResponse.statusCode)")
                    errorMessage = "删除账户失败，请稍后重试"
                }
                isLoading = false
                return false
            }
        } catch {
            print("🗑️ AuthManager: ❌ 删除账户异常: \(error.localizedDescription)")
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            isLoading = false
            return false
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
        pendingEmail = ""  // 🔧 清空待验证邮箱
    }

    private func parseError(_ error: Error) -> String {
        return error.localizedDescription
    }
}
