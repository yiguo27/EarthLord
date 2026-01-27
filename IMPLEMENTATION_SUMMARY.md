# Google 登录实现总结

## ✅ 已完成的工作

### 1. 代码实现

#### 新增文件：
- ✅ `EarthLord/Config/SupabaseConfig.swift` - 统一的 Supabase 客户端配置
- ✅ `EarthLord/Delegates/AppDelegate.swift` - 处理 Google Sign-In 的 URL 回调
- ✅ `GOOGLE_SIGN_IN_SETUP.md` - 详细的配置指南

#### 修改的文件：
- ✅ `AuthManager.swift`
  - 添加了 GoogleSignIn 和 UIKit 导入
  - 添加了 `signInWithGoogle()` 方法
  - 初始化 Google Sign-In 配置

- ✅ `AuthView.swift`
  - 更新 Google 登录按钮，调用实际的登录方法

- ✅ `EarthLordApp.swift`
  - 注册 AppDelegate 用于处理 OAuth 回调

- ✅ `SupabaseTestView.swift`
  - 移除了重复的 supabase 客户端定义，使用统一配置

### 2. 技术架构

```
用户点击登录按钮
    ↓
AuthView.swift 调用 authManager.signInWithGoogle()
    ↓
AuthManager.swift 调用 Google Sign-In SDK
    ↓
Google Sign-In 弹出授权页面
    ↓
用户授权后返回 ID Token
    ↓
使用 ID Token 通过 Supabase 登录
    ↓
登录成功，更新用户状态
```

## ⚠️ 需要手动配置的步骤

### 1. Google Cloud Console 配置
- [ ] 创建 Google Cloud 项目
- [ ] 创建 iOS OAuth 客户端 ID
- [ ] 创建 Web OAuth 客户端 ID（用于 Supabase）
- [ ] 记录客户端 ID 和密钥

### 2. Supabase 配置
- [ ] 在 Supabase Dashboard 启用 Google Provider
- [ ] 配置 Web Client ID 和 Client Secret

### 3. Xcode 项目配置
- [ ] 添加 URL Scheme（客户端 ID 的反转形式）
- [ ] 在 `AuthManager.swift` 中替换 `YOUR_IOS_CLIENT_ID` 为实际的客户端 ID

### 4. 测试
- [ ] 运行应用
- [ ] 测试 Google 登录流程
- [ ] 验证登录成功后的用户状态

## 📝 配置步骤详解

请参考 `GOOGLE_SIGN_IN_SETUP.md` 文件获取详细的配置说明。

## 🔧 需要替换的占位符

在 `AuthManager.swift` 第 56 行：
```swift
GIDSignIn.sharedInstance.configuration = GIDConfiguration(
    clientID: "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com"  // ⚠️ 替换这里
)
```

替换为你从 Google Cloud Console 获取的 iOS 客户端 ID。

## 📱 URL Scheme 配置示例

假设你的 iOS 客户端 ID 是：
```
123456789-abcdef.apps.googleusercontent.com
```

则需要在 Xcode 的 Info > URL Types 中添加：
- **Identifier**: `com.googleusercontent.apps.123456789-abcdef`
- **URL Schemes**: `com.googleusercontent.apps.123456789-abcdef`

## 🐛 常见问题排查

1. **点击按钮没反应**
   - 检查 URL Scheme 是否配置
   - 检查客户端 ID 是否正确

2. **登录后报错 "invalid_client"**
   - 检查 Supabase 中的配置
   - 确认使用的是 Web Client ID（不是 iOS Client ID）

3. **无法跳转回应用**
   - 检查 URL Scheme 是否为客户端 ID 的正确反转形式
   - 检查 AppDelegate 是否正确注册

## 📚 参考资源

- [Google Sign-In for iOS 官方文档](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Supabase Google OAuth 文档](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [GoogleSignIn-iOS GitHub](https://github.com/google/GoogleSignIn-iOS)
