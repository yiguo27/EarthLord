//
//  POIProximitySheet.swift
//  EarthLord
//
//  POI接近弹窗 - 玩家走到POI 50米范围内弹出
//

import SwiftUI
import CoreLocation

struct POIProximitySheet: View {
    /// 当前接近的POI
    let poi: SearchedPOI

    /// 是否正在加载（AI 生成中）
    let isLoading: Bool

    /// 搜刮回调
    let onScavenge: () -> Void

    /// 稍后再说回调
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 顶部图标和标题
            VStack(spacing: 12) {
                // POI类型图标
                ZStack {
                    Circle()
                        .fill(Color(hex: poi.type.colorHex).opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: poi.type.iconName)
                        .font(.system(size: 36))
                        .foregroundColor(Color(hex: poi.type.colorHex))
                }

                // 标题
                Text("发现废墟")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(poi.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // 距离信息
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("距离: \(Int(poi.distance))米")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(8)

            // 提示文字
            Text("这里可能有有用的物资...")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .italic()

            Spacer()
                .frame(height: 10)

            // 按钮区域
            VStack(spacing: 12) {
                // 立即搜刮按钮
                Button(action: onScavenge) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("AI 正在生成...")
                                .font(.system(size: 16, weight: .semibold))
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                            Text("立即搜刮")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(isLoading)

                // 稍后再说按钮
                Button(action: onDismiss) {
                    Text("稍后再说")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(24)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    POIProximitySheet(
        poi: SearchedPOI(
            id: "test",
            name: "全家便利店",
            type: .convenience,
            coordinate: .init(latitude: 31.2, longitude: 121.4),
            distance: 32
        ),
        isLoading: false,
        onScavenge: {},
        onDismiss: {}
    )
}
