//
//  BackpackView.swift
//  EarthLord
//
//  背包管理页面
//  显示物品列表、容量、搜索、筛选功能
//

import SwiftUI

/// 物品分类筛选选项
enum ItemFilterCategory: String, CaseIterable {
    case all = "全部"
    case food = "食物"
    case water = "水"
    case material = "材料"
    case tool = "工具"
    case medical = "医疗"

    /// 转换为 ItemCategory
    func toItemCategory() -> ItemCategory? {
        switch self {
        case .all: return nil
        case .food: return .food
        case .water: return .water
        case .material: return .material
        case .tool: return .tool
        case .medical: return .medical
        }
    }

    /// 分类图标
    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .food: return "fork.knife"
        case .water: return "drop.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.fill"
        case .medical: return "cross.case.fill"
        }
    }
}

struct BackpackView: View {
    // MARK: - Observed Objects

    /// 背包管理器
    @ObservedObject private var inventoryManager = InventoryManager.shared

    // MARK: - State

    /// 筛选后的物品列表
    @State private var filteredItems: [BackpackItem] = []

    /// 当前选中的分类筛选
    @State private var selectedCategory: ItemFilterCategory = .all

    /// 搜索文本
    @State private var searchText = ""

    /// 背包容量设置
    private let maxCapacity = 100
    @State private var currentCapacity = 64

    /// 动画用的容量值
    @State private var animatedCapacity: Double = 0

    // MARK: - Computed Properties

    /// 容量百分比
    private var capacityPercentage: Double {
        return Double(currentCapacity) / Double(maxCapacity)
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage < 0.7 {
            return ApocalypseTheme.success  // 绿色
        } else if capacityPercentage < 0.9 {
            return ApocalypseTheme.warning  // 黄色
        } else {
            return ApocalypseTheme.danger   // 红色
        }
    }

    /// 是否显示容量警告
    private var shouldShowCapacityWarning: Bool {
        return capacityPercentage >= 0.9
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityStatusCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // 搜索框
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // 分类筛选工具栏
                categoryFilterToolbar
                    .padding(.top, 12)

                // 物品列表
                itemListView
                    .padding(.top, 16)
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: searchText) { _ in
            applyFilter()
        }
        .onChange(of: selectedCategory) { _ in
            applyFilter()
        }
        .onChange(of: inventoryManager.items) { _ in
            applyFilter()
            calculateCurrentCapacity()

            // 容量进度条动画
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animatedCapacity = Double(currentCapacity)
            }
        }
        .onAppear {
            // 加载背包数据
            Task {
                await inventoryManager.loadInventory()
            }
        }
    }

    // MARK: - Subviews

    /// 容量状态卡
    private var capacityStatusCard: some View {
        ELCard(padding: 16) {
            VStack(spacing: 12) {
                // 容量数字
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

                    // 百分比
                    Text("\(Int(capacityPercentage * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(capacityColor.opacity(0.2))
                        .cornerRadius(8)
                }

                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.cardBackground.opacity(0.5))
                            .frame(height: 12)

                        // 进度（使用动画值）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [capacityColor, capacityColor.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (animatedCapacity / Double(maxCapacity)), height: 12)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatedCapacity)
                    }
                }
                .frame(height: 12)

                // 警告文字
                if shouldShowCapacityWarning {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.danger)

                        Text("背包快满了！")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.danger)

                        Spacer()
                    }
                }
            }
        }
    }

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索物品名称", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 分类筛选工具栏
    private var categoryFilterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ItemFilterCategory.allCases, id: \.self) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// 分类按钮
    private func categoryButton(for category: ItemFilterCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)

                Text(category.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            }
            .padding(.horizontal, 14)
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

    /// 物品列表视图
    private var itemListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredItems.isEmpty {
                    // 空状态
                    emptyStateView
                        .padding(.top, 60)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    ForEach(filteredItems) { item in
                        if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                            itemCardView(item: item, definition: definition)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .animation(.easeInOut(duration: 0.3), value: filteredItems.map { $0.id })
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: inventoryManager.items.isEmpty ? "backpack" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(inventoryManager.items.isEmpty ? "背包空空如也" : "没有找到相关物品")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text(inventoryManager.items.isEmpty ? "去探索收集物资吧" : "尝试调整搜索或筛选条件")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 如果背包完全为空，显示探索提示
            if inventoryManager.items.isEmpty {
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
                .padding(.top, 8)
            }
        }
    }

    /// 物品卡片视图
    private func itemCardView(item: BackpackItem, definition: ItemDefinition) -> some View {
        ELCard(padding: 14) {
            HStack(spacing: 14) {
                // 左边：圆形图标
                itemIconView(category: definition.category)
                    .frame(width: 50, height: 50)
                    .background(categoryColor(for: definition.category).opacity(0.15))
                    .clipShape(Circle())

                // 中间：物品信息
                VStack(alignment: .leading, spacing: 6) {
                    // 物品名称
                    Text(definition.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 数量和重量
                    HStack(spacing: 12) {
                        // 数量
                        HStack(spacing: 4) {
                            Image(systemName: "number")
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text("x\(item.quantity)")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        // 重量
                        HStack(spacing: 4) {
                            Image(systemName: "scalemass")
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text(String(format: "%.1fkg", definition.weight * Double(item.quantity)))
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    // 品质和稀有度标签
                    HStack(spacing: 8) {
                        // 品质标签（如果有）
                        if let quality = item.quality {
                            qualityBadge(quality: quality)
                        }

                        // 稀有度标签
                        rarityBadge(rarity: definition.rarity)
                    }
                }

                Spacer()

                // 右边：操作按钮
                VStack(spacing: 8) {
                    // 使用按钮
                    Button(action: {
                        print("🔧 使用物品: \(definition.name)")
                        // TODO: 实现使用物品逻辑
                    }) {
                        Text("使用")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 28)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(8)
                    }

                    // 存储按钮
                    Button(action: {
                        print("📦 存储物品: \(definition.name)")
                        // TODO: 实现存储物品逻辑
                    }) {
                        Text("存储")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .frame(width: 50, height: 28)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    /// 物品图标视图
    private func itemIconView(category: ItemCategory) -> some View {
        let iconName: String
        switch category {
        case .water:
            iconName = "drop.fill"
        case .food:
            iconName = "fork.knife"
        case .medical:
            iconName = "cross.case.fill"
        case .material:
            iconName = "cube.fill"
        case .tool:
            iconName = "wrench.fill"
        case .weapon:
            iconName = "shield.fill"
        case .clothing:
            iconName = "tshirt.fill"
        }

        return Image(systemName: iconName)
            .font(.system(size: 24))
            .foregroundColor(categoryColor(for: category))
    }

    /// 物品分类颜色
    private func categoryColor(for category: ItemCategory) -> Color {
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

    /// 品质徽章
    private func qualityBadge(quality: ItemQuality) -> some View {
        let color = qualityColor(for: quality)

        return Text(quality.rawValue)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }

    /// 稀有度徽章
    private func rarityBadge(rarity: ItemRarity) -> some View {
        let color = rarityColor(for: rarity)

        return Text(rarity.displayName)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    /// 品质颜色（根据用户要求）
    private func qualityColor(for quality: ItemQuality) -> Color {
        switch quality {
        case .common:
            return Color.gray        // 普通：灰色
        case .good:
            return Color.green       // 良好：绿色
        case .excellent:
            return Color.blue        // 优秀：蓝色
        case .epic:
            return Color.purple      // 史诗：紫色
        }
    }

    /// 稀有度颜色
    private func rarityColor(for rarity: ItemRarity) -> Color {
        switch rarity {
        case .common:
            return ApocalypseTheme.textMuted
        case .uncommon:
            return Color.green
        case .rare:
            return Color.blue
        case .veryRare:
            return Color.purple
        case .legendary:
            return Color.orange
        }
    }

    // MARK: - Methods

    /// 应用筛选
    private func applyFilter() {
        var items = inventoryManager.items

        // 分类筛选
        if selectedCategory != .all {
            if let category = selectedCategory.toItemCategory() {
                items = items.filter { item in
                    if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                        return definition.category == category
                    }
                    return false
                }
            }
        }

        // 搜索文字筛选
        if !searchText.isEmpty {
            items = items.filter { item in
                if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                    return definition.name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }

        filteredItems = items
    }

    /// 计算当前容量
    private func calculateCurrentCapacity() {
        // 根据物品总重量或数量计算容量
        // 这里简化为计算物品种类数量
        currentCapacity = min(inventoryManager.items.count * 7, maxCapacity)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackpackView()
    }
}
