//
//  EmptyStateTestView.swift
//  EarthLord
//
//  空状态测试页面
//  用于测试各个页面的空状态和错误状态
//

import SwiftUI

struct EmptyStateTestView: View {
    @State private var showEmptyBackpack = false
    @State private var showEmptyPOI = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 标题
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(ApocalypseTheme.warning)

                            Text("空状态测试")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("测试空状态和错误状态显示")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)

                        // 空背包按钮
                        Button(action: {
                            showEmptyBackpack = true
                        }) {
                            testButton(
                                icon: "backpack",
                                title: "空背包状态",
                                description: "查看背包完全为空时的显示"
                            )
                        }

                        // 空POI列表按钮
                        Button(action: {
                            showEmptyPOI = true
                        }) {
                            testButton(
                                icon: "map",
                                title: "空POI列表状态",
                                description: "查看没有POI时的显示"
                            )
                        }

                        // 正常背包（对比）
                        NavigationLink(destination: BackpackView()) {
                            testButton(
                                icon: "backpack.fill",
                                title: "正常背包（对比）",
                                description: "查看有物品时的正常显示"
                            )
                        }

                        // 正常POI列表（对比）
                        NavigationLink(destination: POIListView()) {
                            testButton(
                                icon: "map.fill",
                                title: "正常POI列表（对比）",
                                description: "查看有POI时的正常显示"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("空状态测试")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showEmptyBackpack) {
            EmptyBackpackView()
        }
        .sheet(isPresented: $showEmptyPOI) {
            EmptyPOIListView()
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

/// 空背包视图（用于测试）
struct EmptyBackpackView: View {
    @State private var backpackItems: [BackpackItem] = []
    @State private var filteredItems: [BackpackItem] = []
    @State private var selectedCategory: ItemFilterCategory = .all
    @State private var searchText = ""
    @State private var currentCapacity = 0
    @State private var animatedCapacity: Double = 0

    private let maxCapacity = 100

    private var capacityPercentage: Double {
        return Double(currentCapacity) / Double(maxCapacity)
    }

    private var capacityColor: Color {
        return ApocalypseTheme.success
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 容量状态卡
                    ELCard(padding: 16) {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "backpack.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(ApocalypseTheme.primary)

                                Text("背包容量：")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.textSecondary)

                                Text("\(currentCapacity) / \(maxCapacity)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(capacityColor)

                                Spacer()

                                Text("0%")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(capacityColor.opacity(0.2))
                                    .cornerRadius(8)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(ApocalypseTheme.cardBackground.opacity(0.5))
                                        .frame(height: 12)
                                }
                            }
                            .frame(height: 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // 空状态
                    Spacer()

                    VStack(spacing: 20) {
                        Image(systemName: "backpack")
                            .font(.system(size: 60))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text("背包空空如也")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("去探索收集物资吧")
                            .font(.system(size: 15))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 14))
                                Text("前往资源页 → POI")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(ApocalypseTheme.primary.opacity(0.1))
                            .cornerRadius(20)

                            Text("探索废墟收集物资")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("背包")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

/// 空POI列表视图（用于测试）
struct EmptyPOIListView: View {
    @State private var allPOIs: [POI] = []
    @State private var filteredPOIs: [POI] = []

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 状态栏
                    ELCard(padding: 12) {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(ApocalypseTheme.info)

                                Text("GPS: 22.54, 114.06")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.textSecondary)

                                Spacer()
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(ApocalypseTheme.success)

                                Text("附近发现 0 个地点")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // 空状态
                    Spacer()

                    VStack(spacing: 20) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 60))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text("附近暂无兴趣点")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("点击搜索按钮发现周围的废墟")
                            .font(.system(size: 15))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 16))
                            Text("点击上方搜索按钮")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(ApocalypseTheme.primary.opacity(0.1))
                        .cornerRadius(20)
                    }

                    Spacer()
                }
            }
            .navigationTitle("附近地点")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    EmptyStateTestView()
}
