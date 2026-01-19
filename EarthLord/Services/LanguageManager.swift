//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/19.
//

import SwiftUI
import Combine

// MARK: - 语言选项
enum AppLanguage: String, CaseIterable, Equatable {
    case system = "system"
    case chinese = "zh-Hans"
    case english = "en"

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }

    var icon: String {
        switch self {
        case .system: return "gearshape"
        case .chinese: return "character"
        case .english: return "a.circle"
        }
    }
}

// MARK: - 语言管理器
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private let languageKey = "app_language"

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        }
    }

    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
    }

    // 获取当前应该使用的语言代码
    var effectiveLanguageCode: String {
        switch currentLanguage {
        case .system:
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            if preferredLanguage.hasPrefix("zh") {
                return "zh-Hans"
            } else {
                return "en"
            }
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }

    // 完整翻译字典
    private let translations: [String: String] = [
        // ============ Tab 栏 ============
        "地图": "Map",
        "领地": "Territory",
        "个人": "Profile",
        "更多": "More",

        // ============ 个人中心/更多页面 ============
        "个人中心": "Profile",
        "语言": "Language",
        "账号信息": "Account",
        "通知设置": "Notification Settings",
        "隐私与安全": "Privacy & Security",
        "关于": "About",
        "退出登录": "Sign Out",
        "未登录": "Not Logged In",
        "设置": "Settings",
        "通知": "Notifications",
        "帮助": "Help",

        // ============ 个人页面 - 幸存者档案 ============
        "幸存者档案": "Survivor Profile",
        "Lv.1 新手幸存者": "Lv.1 Novice Survivor",

        // ============ 个人页面 - 生存数据 ============
        "生存数据": "Survival Stats",
        "资源点": "Resources",
        "探索距离": "Distance",
        "生存天数": "Days",

        // ============ 对话框 ============
        "确定要退出登录吗？": "Are you sure you want to sign out?",
        "退出后需要重新登录": "You will need to sign in again",
        "取消": "Cancel",
        "确定": "OK",
        "提示": "Notice",

        // ============ 删除账户 ============
        "删除账户": "Delete Account",
        "删除中...": "Deleting...",
        "确认删除": "Confirm Delete",
        "此操作不可撤销！\n您的所有数据将被永久删除，包括：": "This action cannot be undone!\nAll your data will be permanently deleted, including:",
        "个人资料": "Personal Info",
        "领地数据": "Territory Data",
        "游戏进度": "Game Progress",
        "请输入 DELETE 以确认操作": "Type DELETE to confirm",

        // ============ 登录注册 ============
        "登录": "Sign In",
        "注册": "Sign Up",
        "忘记密码？": "Forgot Password?",
        "找回密码": "Reset Password",
        "或者使用以下方式登录": "Or sign in with",
        "通过 Apple 登录": "Sign in with Apple",
        "通过 Google 登录": "Sign in with Google",
        "输入您的邮箱地址": "Enter your email address",
        "输入您注册时使用的邮箱": "Enter your registered email",
        "设置您的登录密码": "Set your login password",
        "设置您的新密码": "Set your new password",
        "两次输入的密码不一致": "Passwords do not match",
        "返回上一步": "Go Back",
        "请稍候...": "Please wait...",
        "重新发送验证码": "Resend Code",

        // ============ 启动页 ============
        "正在初始化...": "Initializing...",
        "正在加载资源...": "Loading resources...",
        "准备就绪": "Ready",

        // ============ 其他 ============
        "正在检查登录状态...": "Checking login status...",
        "探索和圈占领地": "Explore and claim territory",
        "管理你的领地": "Manage your territory",
        "地球新主": "Earth Lord",

        // ============ 测试 ============
        "Supabase 连接测试": "Supabase Connection Test",
        "Supabase测试": "Supabase Test",
        "测试连接": "Test Connection",
        "测试中...": "Testing...",
        "这里是分支宇宙的测试页": "This is the branch universe test page",
    ]

    // 获取本地化字符串
    func localizedString(_ key: String) -> String {
        if effectiveLanguageCode == "zh-Hans" {
            return key
        }
        return translations[key] ?? key
    }

    // 设置语言
    func setLanguage(_ language: AppLanguage) {
        guard currentLanguage != language else { return }
        currentLanguage = language
    }
}

// MARK: - 本地化字符串扩展
extension String {
    var localized: String {
        return LanguageManager.shared.localizedString(self)
    }
}
