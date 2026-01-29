//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果页面
//  显示探索统计数据、获得物品、排名信息
//

import SwiftUI

struct ExplorationResultView: View {
    // MARK: - Properties

    /// 行走距离（米）
    let distance: Double

    /// 探索时长（秒）
    let duration: Int

    /// 奖励等级
    let tier: RewardTier

    /// 获得的物品
    let items: [RewardItem]

    /// 是否失败（可选）
    var isFailed: Bool = false

    /// 失败原因（可选）
    var failureReason: String = "探索过程中遇到了危险"

    /// 环境变量（用于关闭）
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// 动画状态
    @State private var showContent = false

    /// 数字动画值
    @State private var animatedDistance: Double = 0
    @State private var animatedDuration: Double = 0

    /// 奖励物品显示状态
    @State private var rewardItemsVisible: [Bool] = []

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if isFailed {
                        // 失败状态
                        failureView
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -20)

                        // 确认按钮
                        confirmButton
                            .opacity(showContent ? 1 : 0)
                    } else {
                        // 成功状态
                        // 成就标题区域
                        achievementHeader
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -20)

                        // 统计数据卡片
                        statisticsCard
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)

                        // 奖励物品卡片
                        rewardsCard
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)

                        // 确认按钮
                        confirmButton
                            .opacity(showContent ? 1 : 0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // 初始化奖励物品可见状态
            rewardItemsVisible = Array(repeating: false, count: items.count)

            // 页面内容渐入
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }

            // 数字跳动动画
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                animatedDistance = distance
                animatedDuration = Double(duration)
            }

            // 奖励物品依次出现
            for (index, _) in items.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(index) * 0.2) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        if index < rewardItemsVisible.count {
                            rewardItemsVisible[index] = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    /// 失败状态视图
    private var failureView: some View {
        VStack(spacing: 28) {
            Spacer()
                .frame(height: 40)

            // 错误图标
            ZStack {
                // 背景光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.danger.opacity(0.3),
                                ApocalypseTheme.danger.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                // 主图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.danger)
                    .shadow(color: ApocalypseTheme.danger.opacity(0.5), radius: 10)
            }

            // 标题文字
            VStack(spacing: 12) {
                Text("探索失败")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(failureReason)
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            // 失败提示卡片
            ELCard(padding: 20) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.warning)

                        Text("探索提示")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Spacer()
                    }

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    VStack(alignment: .leading, spacing: 10) {
                        tipRow(icon: "checkmark.circle", text: "选择低危险度的地点")
                        tipRow(icon: "checkmark.circle", text: "携带足够的医疗物资")
                        tipRow(icon: "checkmark.circle", text: "避开高危废墟区域")
                    }
                }
            }

            Spacer()
        }
    }

    /// 提示行
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.success)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    /// 成就标题区域
    private var achievementHeader: some View {
        VStack(spacing: 20) {
            // 大图标（带呼吸动画）
            ZStack {
                // 背景光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.success.opacity(0.3),
                                ApocalypseTheme.success.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                // 主图标
                Image(systemName: "map.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.success)
                    .shadow(color: ApocalypseTheme.success.opacity(0.5), radius: 10)
            }

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("恭喜你完成了一次探索")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.vertical, 20)
    }

    /// 统计数据卡片
    private var statisticsCard: some View {
        ELCard(padding: 20) {
            VStack(spacing: 18) {
                // 标题
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("探索统计")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 统计数据
                VStack(spacing: 16) {
                    // 行走距离
                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.info)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("行走距离")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text(formatDistance(animatedDistance))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }

                        Spacer()
                    }

                    // 探索时长
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.info)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("探索时长")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text(formatDuration(Int(animatedDuration)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }

                        Spacer()
                    }

                    // 奖励等级
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("奖励等级")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text(tier.displayName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }

                        Spacer()

                        Text(tier.description)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    /// 统计数据行
    private func statisticRow(
        icon: String,
        title: String,
        sessionValue: String,
        totalValue: String,
        rank: Int
    ) -> some View {
        VStack(spacing: 12) {
            // 标题和图标
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }

            // 数据行
            HStack(spacing: 16) {
                // 本次
                dataColumn(label: "本次", value: sessionValue)

                Divider()
                    .frame(height: 40)
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 累计
                dataColumn(label: "累计", value: totalValue)

                Divider()
                    .frame(height: 40)
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 排名
                VStack(spacing: 4) {
                    Text("排名")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("#\(rank)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(ApocalypseTheme.success.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
    }

    /// 数据列
    private func dataColumn(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 奖励物品卡片
    private var rewardsCard: some View {
        ELCard(padding: 20) {
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("获得物品")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 物品列表（带动画）
                VStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, reward in
                        if let definition = MockExplorationData.getItemDefinition(by: reward.itemId) {
                            if index < rewardItemsVisible.count && rewardItemsVisible[index] {
                                rewardItemRow(definition: definition, reward: reward, isVisible: true)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                    }
                }

                // 底部提示
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("已添加到背包")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.success)

                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.success.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }

    /// 奖励物品行
    private func rewardItemRow(definition: ItemDefinition, reward: RewardItem, isVisible: Bool) -> some View {
        HStack(spacing: 14) {
            // 物品图标
            Image(systemName: definition.iconName)
                .font(.system(size: 20))
                .foregroundColor(itemCategoryColor(for: definition.category))
                .frame(width: 40, height: 40)
                .background(itemCategoryColor(for: definition.category).opacity(0.15))
                .cornerRadius(10)

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(definition.category.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 数量
            Text("x\(reward.quantity)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)

            // 绿色对勾（带弹跳动画）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(isVisible ? 1.0 : 0.5)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.5).delay(0.1),
                    value: isVisible
                )
        }
        .padding(.vertical, 6)
    }

    /// 确认按钮
    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))

                Text("确定")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
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
            .cornerRadius(14)
            .shadow(
                color: ApocalypseTheme.primary.opacity(0.4),
                radius: 12,
                x: 0,
                y: 6
            )
        }
    }

    // MARK: - Helper Methods

    /// 物品分类颜色
    private func itemCategoryColor(for category: ItemCategory) -> Color {
        switch category {
        case .water:
            return Color.blue
        case .food:
            return Color.orange
        case .medical:
            return Color.red
        case .material:
            return Color.brown
        case .tool:
            return Color.gray
        case .weapon:
            return Color.purple
        case .clothing:
            return Color.green
        }
    }

    /// 格式化距离
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return String(format: "%.0f米", distance)
        } else {
            return String(format: "%.1f公里", distance / 1000.0)
        }
    }

    /// 格式化面积
    private func formatArea(_ area: Double) -> String {
        if area < 10000 {
            return String(format: "%.0f㎡", area)
        } else {
            return String(format: "%.1f万㎡", area / 10000.0)
        }
    }

    /// 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return String(format: "%d小时%d分钟", hours, minutes)
        } else {
            return String(format: "%d分钟", minutes)
        }
    }
}

// MARK: - Preview

#Preview {
    ExplorationResultView(result: MockExplorationData.mockExplorationResult)
}
