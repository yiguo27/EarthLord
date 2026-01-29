//
//  POIDetailView.swift
//  EarthLord
//
//  POI详情页面
//  显示POI详细信息、操作按钮、探索功能
//

import SwiftUI

/// 危险等级
enum DangerLevel: String {
    case safe = "安全"
    case low = "低危"
    case medium = "中危"
    case high = "高危"

    /// 危险等级颜色
    var color: Color {
        switch self {
        case .safe:
            return ApocalypseTheme.success     // 绿色
        case .low:
            return Color.yellow                // 黄色
        case .medium:
            return Color.orange                // 橙色
        case .high:
            return ApocalypseTheme.danger      // 红色
        }
    }

    /// 危险等级图标
    var iconName: String {
        switch self {
        case .safe:
            return "checkmark.shield.fill"
        case .low:
            return "exclamationmark.shield.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high:
            return "xmark.shield.fill"
        }
    }
}

/// POI来源
enum POISource: String {
    case mapData = "地图数据"
    case manualAdd = "手动添加"
    case userReport = "用户上报"
}

struct POIDetailView: View {
    // MARK: - Properties

    /// POI数据
    let poi: POI

    /// 环境变量（用于返回）
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// 是否显示探索结果弹窗
    @State private var showExplorationResult = false

    /// POI状态（可修改）
    @State private var currentStatus: POIStatus

    /// 物资状态（可修改）
    @State private var hasResources: Bool

    /// 图标呼吸动画
    @State private var iconScale: CGFloat = 1.0

    /// 搜寻按钮缩放
    @State private var searchButtonScale: CGFloat = 1.0

    /// 危险等级（模拟数据）
    private let dangerLevel: DangerLevel

    /// 来源（模拟数据）
    private let source: POISource = .mapData

    /// 距离（模拟数据，来自POI）
    private var distance: Double {
        return poi.distanceFromUser ?? 350.0
    }

    // MARK: - Initialization

    init(poi: POI) {
        self.poi = poi
        _currentStatus = State(initialValue: poi.status)
        _hasResources = State(initialValue: poi.hasResources)

        // 根据POI类型模拟危险等级
        switch poi.type {
        case .hospital:
            dangerLevel = .medium
        case .factory:
            dangerLevel = .high
        case .supermarket:
            dangerLevel = .low
        case .pharmacy:
            dangerLevel = .low
        case .gasStation:
            dangerLevel = .medium
        default:
            dangerLevel = .safe
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerImageView

                    // 内容区域
                    VStack(spacing: 16) {
                        // 信息卡片
                        infoCard

                        // 操作按钮区域
                        actionButtonsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            explorationResultSheet
        }
    }

    // MARK: - Subviews

    /// 顶部大图区域
    private var headerImageView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        poiTypeColor(for: poi.type),
                        poiTypeColor(for: poi.type).opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 中间大图标（带呼吸动画）
                VStack {
                    Spacer()

                    Image(systemName: poiTypeIcon(for: poi.type))
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .scaleEffect(iconScale)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                            ) {
                                iconScale = 1.1
                            }
                        }

                    Spacer()
                }

                // 底部半透明黑色遮罩 + 文字
                VStack(spacing: 8) {
                    Text(poi.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(poi.type.rawValue)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0),
                            Color.black.opacity(0.7)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: UIScreen.main.bounds.height / 3)
    }

    /// 信息卡片
    private var infoCard: some View {
        ELCard(padding: 20) {
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("详细信息")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 信息行
                VStack(spacing: 14) {
                    // 距离
                    infoRow(
                        icon: "location.fill",
                        label: "距离",
                        value: formatDistance(distance),
                        valueColor: ApocalypseTheme.info
                    )

                    // 物资状态
                    infoRow(
                        icon: "cube.box.fill",
                        label: "物资状态",
                        value: hasResources ? "有物资" : "已清空",
                        valueColor: hasResources ? ApocalypseTheme.success : ApocalypseTheme.textMuted
                    )

                    // 危险等级
                    HStack(spacing: 12) {
                        Image(systemName: dangerLevel.iconName)
                            .font(.system(size: 16))
                            .foregroundColor(dangerLevel.color)
                            .frame(width: 24)

                        Text("危险等级")
                            .font(.system(size: 15))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Spacer()

                        Text(dangerLevel.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(dangerLevel.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(dangerLevel.color.opacity(0.15))
                            .cornerRadius(8)
                    }

                    // 来源
                    infoRow(
                        icon: "map.fill",
                        label: "来源",
                        value: source.rawValue,
                        valueColor: ApocalypseTheme.textPrimary
                    )

                    // 发现状态
                    infoRow(
                        icon: "eye.fill",
                        label: "发现状态",
                        value: currentStatus.rawValue,
                        valueColor: statusColor(for: currentStatus)
                    )
                }
            }
        }
    }

    /// 信息行
    private func infoRow(icon: String, label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }

    /// 操作按钮区域
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // 主按钮："搜寻此POI"
            searchButton

            // 两个小按钮并排
            HStack(spacing: 12) {
                // 标记已发现
                secondaryButton(
                    title: "标记已发现",
                    icon: "eye.fill",
                    action: {
                        markAsDiscovered()
                    }
                )

                // 标记无物资
                secondaryButton(
                    title: "标记无物资",
                    icon: "xmark.circle.fill",
                    action: {
                        markAsNoResources()
                    }
                )
            }
        }
    }

    /// 主搜寻按钮
    private var searchButton: some View {
        let isDisabled = currentStatus == .looted || !hasResources

        return Button(action: {
            if !isDisabled {
                // 点击缩放动画
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    searchButtonScale = 0.95
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        searchButtonScale = 1.0
                    }
                }

                performExploration()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 20))

                Text(isDisabled ? "此地点已被搜空" : "搜寻此POI")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if isDisabled {
                        Color.gray
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(14)
            .shadow(
                color: isDisabled ? Color.clear : ApocalypseTheme.primary.opacity(0.4),
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .scaleEffect(searchButtonScale)
        .disabled(isDisabled)
    }

    /// 次要按钮
    private func secondaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(ApocalypseTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }

    /// 探索结果弹窗
    private var explorationResultSheet: some View {
        ExplorationResultView(result: MockExplorationData.mockExplorationResult)
            .onDisappear {
                // 探索结束后标记为已清空
                currentStatus = .looted
                hasResources = false
            }
    }

    // MARK: - Helper Methods

    /// POI类型图标
    private func poiTypeIcon(for type: POIType) -> String {
        switch type {
        case .hospital:
            return "cross.case.fill"
        case .supermarket:
            return "cart.fill"
        case .factory:
            return "building.2.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        default:
            return "mappin.circle.fill"
        }
    }

    /// POI类型颜色
    private func poiTypeColor(for type: POIType) -> Color {
        switch type {
        case .hospital:
            return Color.red
        case .supermarket:
            return Color.green
        case .factory:
            return Color.gray
        case .pharmacy:
            return Color.purple
        case .gasStation:
            return Color.orange
        default:
            return ApocalypseTheme.primary
        }
    }

    /// POI状态颜色
    private func statusColor(for status: POIStatus) -> Color {
        switch status {
        case .undiscovered:
            return ApocalypseTheme.textMuted
        case .discovered:
            return ApocalypseTheme.info
        case .looted:
            return ApocalypseTheme.textSecondary
        }
    }

    /// 格式化距离
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return String(format: "%.0f 米", distance)
        } else {
            return String(format: "%.1f 公里", distance / 1000.0)
        }
    }

    // MARK: - Actions

    /// 执行搜寻
    private func performExploration() {
        print("🔍 开始搜寻 POI: \(poi.name)")
        showExplorationResult = true
    }

    /// 标记为已发现
    private func markAsDiscovered() {
        currentStatus = .discovered
        print("👁️ 标记 \(poi.name) 为已发现")
        // TODO: 同步到数据库
    }

    /// 标记为无物资
    private func markAsNoResources() {
        hasResources = false
        currentStatus = .looted
        print("❌ 标记 \(poi.name) 为无物资")
        // TODO: 同步到数据库
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.mockPOIs[0])
    }
}
