//
//  AuthManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/12.
//

import Foundation
import Combine
import Supabase

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
