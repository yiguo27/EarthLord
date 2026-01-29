//
//  ELCard.swift
//  EarthLord
//
//  通用卡片组件 - 用于显示内容的统一容器
//

import SwiftUI

/// 通用卡片组件
struct ELCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 4
    var backgroundColor: Color = ApocalypseTheme.cardBackground

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 4,
        backgroundColor: Color = ApocalypseTheme.cardBackground,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.2), radius: shadowRadius, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack(spacing: 16) {
            ELCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("标题")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("这是一个测试卡片")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            ELCard(backgroundColor: ApocalypseTheme.primary) {
                Text("主题色卡片")
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}
