# Google Sign-In 配置指南

## 1. 在 Google Cloud Console 创建 OAuth 客户端

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建或选择一个项目
3. 启用 Google Sign-In API
4. 前往 **凭据** > **创建凭据** > **OAuth 客户端 ID**

### 创建 iOS OAuth 客户端

- **应用类型**: iOS
- **名称**: EarthLord iOS
- **Bundle ID**: `com.yiguo.EarthLord`

创建后，你会得到：
- **客户端 ID**: 类似 `xxxxx.apps.googleusercontent.com`

记录下这个客户端 ID，后续需要用到。

### 创建 Web OAuth 客户端（用于 Supabase）

- **应用类型**: Web 应用
- **名称**: EarthLord Supabase
- **已获授权的重定向 URI**: `https://hrtdgvplerzybnodjqmk.supabase.co/auth/v1/callback`

创建后，你会得到：
- **客户端 ID**: Web Client ID
- **客户端密钥**: Client Secret

## 2. 在 Supabase 配置 Google Provider

1. 登录 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择你的项目: `hrtdgvplerzybnodjqmk`
3. 前往 **Authentication** > **Providers**
4. 找到 **Google** 并启用
5. 填入 Web OAuth 客户端的：
   - **Client ID** (Web)
   - **Client Secret** (Web)
6. 保存设置

## 3. 配置 Xcode 项目

### 3.1 添加 URL Scheme

1. 在 Xcode 中打开项目
2. 选择 **EarthLord** target
3. 前往 **Info** 标签页
4. 展开 **URL Types** 部分
5. 点击 **+** 添加新的 URL Scheme：
   - **Identifier**: `com.googleusercontent.apps.YOUR_CLIENT_ID`
   - **URL Schemes**: 输入你的 iOS 客户端 ID 的**反转形式**
     - 例如，如果客户端 ID 是 `123456.apps.googleusercontent.com`
     - 则输入：`com.googleusercontent.apps.123456`

### 3.2 配置 Google Client ID

在 `AuthManager.swift` 中，需要初始化 Google Sign-In 配置。

在 `AuthManager` 的 `init()` 方法中添加：

```swift
private init() {
    // 配置 Google Sign-In
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(
        clientID: "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com"
    )
    Task { await setupAuthListener() }
}
```

将 `YOUR_IOS_CLIENT_ID` 替换为你在 Google Cloud Console 创建的 iOS 客户端 ID。

## 4. 测试 Google 登录

1. 运行应用
2. 在登录页面点击 **通过 Google 登录** 按钮
3. 系统会打开 Google 登录页面
4. 选择账户并授权
5. 登录成功后会自动返回应用

## 常见问题

### Q: 点击按钮没有反应
A: 检查是否正确配置了 URL Scheme 和客户端 ID

### Q: 登录失败显示 "invalid_client"
A: 检查 Supabase 中的 Web Client ID 和 Client Secret 是否正确

### Q: 无法跳转回应用
A: 检查 URL Scheme 是否正确配置为客户端 ID 的反转形式

### Q: 测试账号无法登录
A: 确保在 Google Cloud Console 中将测试账号添加到测试用户列表

## 参考文档

- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Supabase Google OAuth](https://supabase.com/docs/guides/auth/social-login/auth-google)
