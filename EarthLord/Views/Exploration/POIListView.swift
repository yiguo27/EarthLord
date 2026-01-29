//
//  POIListView.swift
//  EarthLord
//
//  附近兴趣点列表页面
//  显示POI列表、搜索、筛选功能
//

import SwiftUI

/// POI 类型筛选选项
enum POIFilterType: String, CaseIterable {
    case all = "全部"
    case hospital = "医院"
    case supermarket = "超市"
    case factory = "工厂"
    case pharmacy = "药店"
    case gasStation = "加油站"

    /// 转换为 POIType
    func toPOIType() -> POIType? {
        switch self {
        case .all: return nil
        case .hospital: return .hospital
        case .supermarket: return .supermarket
        case .factory: return .factory
        case .pharmacy: return .pharmacy
        case .gasStation: return .gasStation
        }
    }
}

struct POIListView: View {
    // MARK: - State

    /// 所有POI数据
    @State private var allPOIs: [POI] = MockExplorationData.mockPOIs

    /// 当前筛选的POI列表
    @State private var filteredPOIs: [POI] = MockExplorationData.mockPOIs

    /// 当前选中的筛选类型
    @State private var selectedFilter: POIFilterType = .all

    /// 是否正在搜索
    @State private var isSearching = false

    /// 搜索按钮缩放状态
    @State private var searchButtonScale: CGFloat = 1.0

    /// 列表项是否已加载（用于淡入动画）
    @State private var itemsLoaded = false

    /// GPS 坐标（模拟数据）
    private let mockGPSCoordinate = (latitude: 22.54, longitude: 114.06)

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // 筛选工具栏
                filterToolbar
                    .padding(.top, 16)

                // POI 列表
                poiListView
                    .padding(.top, 16)
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // 触发列表淡入动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                itemsLoaded = true
            }
        }
    }

    // MARK: - Subviews

    /// 状态栏
    private var statusBar: some View {
        ELCard(padding: 12) {
            VStack(spacing: 8) {
                // GPS 坐标
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.info)

                    Text("GPS: \(String(format: "%.2f", mockGPSCoordinate.latitude)), \(String(format: "%.2f", mockGPSCoordinate.longitude))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()
                }

                // 发现数量
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("附近发现 \(filteredPOIs.count) 个地点")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    /// 搜索按钮
    private var searchButton: some View {
        Button(action: {
            // 点击缩放动画
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                searchButtonScale = 0.95
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    searchButtonScale = 1.0
                }
            }

            performSearch()
        }) {
            HStack(spacing: 12) {
                if isSearching {
                    // 加载动画
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    // 搜索图标
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(searchButtonScale)
        .disabled(isSearching)
    }

    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(POIFilterType.allCases, id: \.self) { filterType in
                    filterButton(for: filterType)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// 筛选按钮
    private func filterButton(for filterType: POIFilterType) -> some View {
        let isSelected = selectedFilter == filterType

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filterType
                applyFilter()
            }
        }) {
            Text(filterType.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                )
        }
    }

    /// POI 列表视图
    private var poiListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    // 空状态
                    emptyStateView
                        .padding(.top, 60)
                } else {
                    ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            poiCardView(poi: poi)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(itemsLoaded ? 1 : 0)
                        .offset(y: itemsLoaded ? 0 : 20)
                        .animation(
                            .easeOut(duration: 0.4).delay(Double(index) * 0.1),
                            value: itemsLoaded
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: allPOIs.isEmpty ? "map.fill" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(allPOIs.isEmpty ? "附近暂无兴趣点" : "没有找到该类型的地点")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text(allPOIs.isEmpty ? "点击搜索按钮发现周围的废墟" : "尝试调整筛选条件或搜索其他类型")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 如果完全没有POI，显示搜索提示
            if allPOIs.isEmpty {
                Button(action: {
                    performSearch()
                }) {
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
                .padding(.top, 8)
            }
        }
    }

    /// POI 卡片视图
    private func poiCardView(poi: POI) -> some View {
        ELCard(padding: 16) {
            HStack(spacing: 16) {
                // 类型图标
                poiTypeIcon(for: poi.type)
                    .frame(width: 50, height: 50)
                    .background(poiTypeColor(for: poi.type).opacity(0.15))
                    .cornerRadius(10)

                // 信息区域
                VStack(alignment: .leading, spacing: 6) {
                    // 名称
                    Text(poi.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 类型
                    Text(poi.type.rawValue)
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 状态行
                    HStack(spacing: 12) {
                        // 发现状态
                        statusBadge(
                            text: poi.status.rawValue,
                            color: statusColor(for: poi.status)
                        )

                        // 物资状态
                        if poi.status != .undiscovered {
                            statusBadge(
                                text: poi.hasResources ? "有物资" : "已搜空",
                                color: poi.hasResources ? ApocalypseTheme.success : ApocalypseTheme.textMuted
                            )
                        }
                    }
                }

                Spacer()

                // 右侧箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    /// 状态徽章
    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    /// POI 类型图标
    private func poiTypeIcon(for type: POIType) -> some View {
        let iconName: String
        switch type {
        case .hospital:
            iconName = "cross.case.fill"
        case .supermarket:
            iconName = "cart.fill"
        case .factory:
            iconName = "building.2.fill"
        case .pharmacy:
            iconName = "pills.fill"
        case .gasStation:
            iconName = "fuelpump.fill"
        default:
            iconName = "mappin.circle.fill"
        }

        return Image(systemName: iconName)
            .font(.system(size: 24))
            .foregroundColor(poiTypeColor(for: type))
    }

    /// POI 类型颜色
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
            return ApocalypseTheme.textSecondary
        }
    }

    /// POI 状态颜色
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

    // MARK: - Methods

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 模拟网络请求延迟 1.5 秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            print("🔍 搜索完成")
            // TODO: 实际搜索逻辑，更新 allPOIs 数据
        }
    }

    /// 应用筛选
    private func applyFilter() {
        if selectedFilter == .all {
            filteredPOIs = allPOIs
        } else {
            if let poiType = selectedFilter.toPOIType() {
                filteredPOIs = allPOIs.filter { $0.type == poiType }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIListView()
    }
}
