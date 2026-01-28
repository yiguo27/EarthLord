//
//  ModernAuthTheme.swift
//  EarthLord
//
//  现代化认证界面设计系统
//

import SwiftUI

/// 现代化认证主题 - 基于设计最佳实践
enum ModernAuthTheme {
    // MARK: - 间距系统（8pt 网格）
    static let spacing2: CGFloat = 2
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    static let spacing40: CGFloat = 40
    static let spacing48: CGFloat = 48

    // MARK: - 圆角系统
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusXLarge: CGFloat = 24

    // MARK: - 字体系统
    static func title1() -> Font { .system(size: 32, weight: .bold) }
    static func title2() -> Font { .system(size: 24, weight: .semibold) }
    static func title3() -> Font { .system(size: 20, weight: .semibold) }
    static func body() -> Font { .system(size: 16, weight: .regular) }
    static func bodyMedium() -> Font { .system(size: 16, weight: .medium) }
    static func bodySemibold() -> Font { .system(size: 16, weight: .semibold) }
    static func caption() -> Font { .system(size: 14, weight: .regular) }
    static func captionMedium() -> Font { .system(size: 14, weight: .medium) }
    static func small() -> Font { .system(size: 12, weight: .regular) }

    // MARK: - 阴影系统
    static func cardShadow() -> some View {
        EmptyView()
            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 2)
            .shadow(color: Color.black.opacity(0.05), radius: 16, y: 4)
    }

    static func buttonShadow() -> some View {
        EmptyView()
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 12, y: 4)
    }

    // MARK: - 渐变系统
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.06, green: 0.06, blue: 0.08), location: 0.0),
            .init(color: Color(red: 0.08, green: 0.08, blue: 0.10), location: 0.5),
            .init(color: Color(red: 0.05, green: 0.05, blue: 0.07), location: 1.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [
            ApocalypseTheme.primary,
            ApocalypseTheme.primaryDark
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 0.14, green: 0.14, blue: 0.16), location: 0.0),
            .init(color: Color(red: 0.12, green: 0.12, blue: 0.14), location: 1.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
