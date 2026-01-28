//
//  ModernAuthComponents.swift
//  EarthLord
//
//  现代化认证界面组件
//

import SwiftUI

// MARK: - 现代化输入框
struct ModernAuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    @State private var showPassword: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ModernAuthTheme.spacing8) {
            HStack(spacing: ModernAuthTheme.spacing12) {
                // 图标
                Image(systemName: icon)
                    .font(ModernAuthTheme.body())
                    .foregroundColor(isFocused ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)

                // 输入框
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                        .font(ModernAuthTheme.body())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .autocapitalization(.none)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .font(ModernAuthTheme.body())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .textContentType(isSecure ? .password : .emailAddress)
                        .focused($isFocused)
                }

                // 密码显示/隐藏按钮
                if isSecure {
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(ModernAuthTheme.body())
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ModernAuthTheme.spacing16)
            .padding(.vertical, ModernAuthTheme.spacing16)
            .background(
                ZStack {
                    // 背景渐变
                    RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                        .fill(ModernAuthTheme.cardGradient)

                    // 边框
                    RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                        .strokeBorder(
                            isFocused ? ApocalypseTheme.primary : Color.white.opacity(0.1),
                            lineWidth: isFocused ? 2 : 1
                        )
                }
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - 现代化按钮
struct ModernAuthButton: View {
    let title: String
    var isLoading: Bool = false
    var style: ButtonStyle = .primary
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    enum ButtonStyle {
        case primary
        case secondary
        case ghost
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernAuthTheme.spacing8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.9)
                }

                Text(title)
                    .font(ModernAuthTheme.bodySemibold())
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundView)
            .contentShape(Rectangle())
        }
        .disabled(isLoading || !isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                .fill(isEnabled ? ModernAuthTheme.primaryGradient : LinearGradient(
                    colors: [ApocalypseTheme.textMuted],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        case .secondary:
            RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                .fill(ModernAuthTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                        .stroke(ApocalypseTheme.primary, lineWidth: 1.5)
                )
        case .ghost:
            Color.clear
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return ApocalypseTheme.primary
        case .ghost:
            return ApocalypseTheme.textSecondary
        }
    }
}

// MARK: - 现代化 Logo
struct ModernLogoView: View {
    var body: some View {
        VStack(spacing: ModernAuthTheme.spacing16) {
            // Logo 图标
            ZStack {
                // 外圈光晕（更微妙）
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ApocalypseTheme.primary.opacity(0.15),
                                ApocalypseTheme.primary.opacity(0)
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                // Logo 背景
                Circle()
                    .fill(ModernAuthTheme.primaryGradient)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                // 地球图标
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.white)
            }

            // 标题
            VStack(spacing: ModernAuthTheme.spacing4) {
                Text("地球新主")
                    .font(ModernAuthTheme.title1())
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("EARTH LORD")
                    .font(ModernAuthTheme.small())
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .tracking(4)
            }
        }
    }
}

// MARK: - 现代化步骤指示器
struct ModernStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: ModernAuthTheme.spacing12) {
            ForEach(1...totalSteps, id: \.self) { step in
                // 圆点
                Circle()
                    .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(width: step == currentStep ? 10 : 8, height: step == currentStep ? 10 : 8)
                    .overlay(
                        Circle()
                            .stroke(
                                step == currentStep ? ApocalypseTheme.primary : Color.clear,
                                lineWidth: 2
                            )
                            .frame(width: 16, height: 16)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)

                // 连接线
                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(width: 40, height: 2)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
        }
        .padding(.vertical, ModernAuthTheme.spacing12)
    }
}

// MARK: - 社交登录按钮
struct SocialLoginButton: View {
    let icon: String
    let title: String
    let provider: SocialProvider
    let action: () -> Void

    enum SocialProvider {
        case apple
        case google

        var backgroundColor: Color {
            switch self {
            case .apple: return Color.black
            case .google: return Color.white
            }
        }

        var foregroundColor: Color {
            switch self {
            case .apple: return Color.white
            case .google: return Color.black
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernAuthTheme.spacing12) {
                Image(systemName: icon)
                    .font(.system(size: 20))

                Text(title)
                    .font(ModernAuthTheme.bodyMedium())
            }
            .foregroundColor(provider.foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                    .fill(provider.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Toast 通知
struct ModernToast: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: ModernAuthTheme.spacing12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text(message)
                    .font(ModernAuthTheme.caption())
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, ModernAuthTheme.spacing20)
            .padding(.vertical, ModernAuthTheme.spacing16)
            .background(
                RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernAuthTheme.radiusMedium)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            )
            .padding(.horizontal, ModernAuthTheme.spacing24)
            .padding(.bottom, ModernAuthTheme.spacing40 + 60)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: message)
    }
}

// MARK: - 加载遮罩
struct ModernLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: ModernAuthTheme.spacing20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)

                Text("请稍候...")
                    .font(ModernAuthTheme.caption())
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(ModernAuthTheme.spacing40)
            .background(
                RoundedRectangle(cornerRadius: ModernAuthTheme.radiusLarge)
                    .fill(ModernAuthTheme.cardGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernAuthTheme.radiusLarge)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: true)
    }
}
