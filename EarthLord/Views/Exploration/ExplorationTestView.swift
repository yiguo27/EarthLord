//
//  ExplorationTestView.swift
//  EarthLord
//
//  探索模块测试页面
//  用于快速测试各个探索相关页面
//

import SwiftUI

struct ExplorationTestView: View {
    @State private var showPOIList = false
    @State private var showBackpack = false
    @State private var showExplorationResult = false
    @State private var showExplorationFailure = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 标题
                        VStack(spacing: 8) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 60))
                                .foregroundColor(ApocalypseTheme.primary)

                            Text("探索模块测试")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("点击按钮测试各个页面")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)

                        // POI列表按钮
                        NavigationLink(destination: POIListView()) {
                            testButton(
                                icon: "map",
                                title: "POI列表",
                                description: "查看附近兴趣点"
                            )
                        }

                        // 背包按钮
                        NavigationLink(destination: BackpackView()) {
                            testButton(
                                icon: "backpack.fill",
                                title: "背包管理",
                                description: "查看和管理物品"
                            )
                        }

                        // POI详情按钮
                        NavigationLink(destination: POIDetailView(poi: MockExplorationData.mockPOIs[0])) {
                            testButton(
                                icon: "info.circle.fill",
                                title: "POI详情",
                                description: "查看单个POI详情"
                            )
                        }

                        // 探索成功结果按钮
                        Button(action: {
                            showExplorationResult = true
                        }) {
                            testButton(
                                icon: "gift.fill",
                                title: "探索结果（成功）",
                                description: "查看探索完成后的奖励"
                            )
                        }

                        // 探索失败结果按钮
                        Button(action: {
                            showExplorationFailure = true
                        }) {
                            testButton(
                                icon: "exclamationmark.triangle.fill",
                                title: "探索结果（失败）",
                                description: "查看探索失败的提示"
                            )
                        }

                        // 空状态测试按钮
                        NavigationLink(destination: EmptyStateTestView()) {
                            testButton(
                                icon: "tray",
                                title: "空状态测试",
                                description: "测试空背包和空POI列表"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("探索模块")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView(result: MockExplorationData.mockExplorationResult)
        }
        .sheet(isPresented: $showExplorationFailure) {
            ExplorationResultView(
                result: MockExplorationData.mockExplorationResult,
                isFailed: true,
                failureReason: "遭遇了变异生物，不得不撤退"
            )
        }
    }

    /// 测试按钮
    private func testButton(icon: String, title: String, description: String) -> some View {
        ELCard(padding: 20) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 50, height: 50)
                    .background(ApocalypseTheme.primary.opacity(0.15))
                    .cornerRadius(12)

                // 文字
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

#Preview {
    ExplorationTestView()
}
