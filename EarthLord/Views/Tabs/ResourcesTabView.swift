//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源模块主入口页面
//  包含POI、背包、已购、领地、交易等功能
//

import SwiftUI

/// 资源分段选项
enum ResourceSegment: String, CaseIterable, Identifiable {
    case poi = "POI"
    case backpack = "背包"
    case purchased = "已购"
    case territory = "领地"
    case trading = "交易"

    var id: String { rawValue }
}

struct ResourcesTabView: View {
    // MARK: - State

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（模拟数据）
    @State private var tradingEnabled = false

    /// 语言管理器
    @ObservedObject private var languageManager = LanguageManager.shared

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部区域
                    headerView
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Subviews

    /// 顶部区域
    private var headerView: some View {
        HStack {
            // 标题（如果需要额外显示）
            // Text("资源管理")
            //     .font(.system(size: 20, weight: .bold))
            //     .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 交易开关
            HStack(spacing: 8) {
                Text("交易")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Toggle("", isOn: $tradingEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(0.9)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(20)
        }
    }

    /// 分段选择器
    private var segmentPicker: some View {
        Picker("资源分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases) { segment in
                Text(segment.rawValue)
                    .tag(segment)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    /// 内容区域
    private var contentView: some View {
        Group {
            switch selectedSegment {
            case .poi:
                // POI 列表
                POIListView()

            case .backpack:
                // 背包管理
                BackpackView()

            case .purchased:
                // 已购（占位）
                placeholderView(
                    icon: "bag.fill",
                    title: "已购功能",
                    description: "查看已购买的物品和资源"
                )

            case .territory:
                // 领地资源（占位）
                placeholderView(
                    icon: "map.fill",
                    title: "领地资源",
                    description: "管理领地内的资源和建筑"
                )

            case .trading:
                // 交易（占位）
                placeholderView(
                    icon: "arrow.left.arrow.right",
                    title: "交易功能",
                    description: "与其他玩家交易物品"
                )
            }
        }
    }

    /// 占位视图
    private func placeholderView(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 标题
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 描述
            Text(description)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 功能开发中标签
            Text("功能开发中")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.primary)
                .cornerRadius(20)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
