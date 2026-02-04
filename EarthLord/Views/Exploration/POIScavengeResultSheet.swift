//
//  POIScavengeResultSheet.swift
//  EarthLord
//
//  POI搜刮结果视图 - 显示 AI 生成的物品（名称、故事、稀有度）
//

import SwiftUI
import CoreLocation

struct POIScavengeResultSheet: View {
    /// 搜刮的POI
    let poi: SearchedPOI

    /// 搜刮结果列表（含 AI 生成信息和库存映射）
    let results: [ScavengeResult]

    /// 确认回调
    let onConfirm: () -> Void

    /// 物品依次出现动画状态
    @State private var showItems: [Bool] = []

    /// 已展开 story 的物品 ID 集合
    @State private var expandedStories: Set<UUID> = []

    var body: some View {
        VStack(spacing: 24) {
            // 成功图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ApocalypseTheme.success)
            }

            // 标题
            VStack(spacing: 8) {
                Text("搜刮成功！")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: poi.type.colorHex))

                    Text(poi.name)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 物品列表
            VStack(alignment: .leading, spacing: 12) {
                Text("获得物品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                VStack(spacing: 10) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        itemCard(result: result)
                            .opacity(index < showItems.count && showItems[index] ? 1 : 0)
                            .offset(y: index < showItems.count && showItems[index] ? 0 : 20)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.15),
                                value: showItems
                            )
                    }
                }
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)

            Spacer()

            // 确认按钮
            Button(action: onConfirm) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))

                    Text("确认")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(ApocalypseTheme.success)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(ApocalypseTheme.background)
        .onAppear {
            // 初始化动画状态
            showItems = Array(repeating: false, count: results.count)

            // 依次显示物品
            for index in results.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15 + 0.3) {
                    if index < showItems.count {
                        showItems[index] = true
                    }
                }
            }
        }
    }

    // MARK: - 物品卡片（含可展开 story）

    private func itemCard(result: ScavengeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 主行：图标 + 名称 + 稀有度徽章
            HStack(spacing: 12) {
                // 分类图标
                Image(systemName: categoryIcon(for: result.aiItem.category))
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor(for: result.aiItem.category))
                    .frame(width: 40, height: 40)
                    .background(categoryColor(for: result.aiItem.category).opacity(0.15))
                    .cornerRadius(8)

                // AI 生成名称
                Text(result.aiItem.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                // 稀有度徽章
                rarityBadge(result.aiItem.rarity)
            }

            // 可展开 story
            if !result.aiItem.story.isEmpty {
                Button(action: {
                    if expandedStories.contains(result.id) {
                        expandedStories.remove(result.id)
                    } else {
                        expandedStories.insert(result.id)
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.aiItem.story)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .italic()
                            .lineLimit(expandedStories.contains(result.id) ? nil : 1)

                        Text(expandedStories.contains(result.id) ? "收起 ▲" : "展开 ▼")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 稀有度徽章

    private func rarityBadge(_ rarity: String) -> some View {
        Text(rarityDisplayName(rarity))
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(rarityColor(rarity))
            .cornerRadius(10)
    }

    private func rarityDisplayName(_ rarity: String) -> String {
        switch rarity {
        case "common":    return "常见"
        case "uncommon":  return "优秀"
        case "rare":      return "稀有"
        case "epic":      return "史诗"
        case "legendary": return "传奇"
        default:          return "常见"
        }
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "common":    return Color.gray
        case "uncommon":  return Color.green
        case "rare":      return Color.blue
        case "epic":      return Color.purple
        case "legendary": return Color(red: 0.96, green: 0.75, blue: 0.0)  // 金色
        default:          return Color.gray
        }
    }

    // MARK: - 分类图标和颜色

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "医疗": return "cross.case.fill"
        case "食物": return "cube.box.fill"
        case "水":   return "drop.fill"
        case "工具": return "wrench.fill"
        case "武器": return "shield.fill"
        case "材料": return "square.fill.on.square.fill"
        case "服装": return "person.fill"
        default:    return "square.fill"
        }
    }

    private func categoryColor(for category: String) -> Color {
        switch category {
        case "医疗": return Color.red
        case "食物": return Color.orange
        case "水":   return Color.blue
        case "工具": return Color.gray
        case "武器": return Color.purple
        case "材料": return Color.brown
        case "服装": return Color.green
        default:    return Color.gray
        }
    }
}

// MARK: - Preview

#Preview {
    POIScavengeResultSheet(
        poi: SearchedPOI(
            id: "test",
            name: "协和医院急诊室",
            type: .hospital,
            coordinate: .init(latitude: 39.9, longitude: 116.4),
            distance: 28
        ),
        results: [
            ScavengeResult(
                aiItem: AIGeneratedItem(
                    name: "「最后的希望」应急包",
                    category: "医疗",
                    rarity: "epic",
                    story: "急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它。"
                ),
                rewardItem: RewardItem(id: "1", itemId: "item-medical-002", quantity: 1, quality: .excellent)
            ),
            ScavengeResult(
                aiItem: AIGeneratedItem(
                    name: "护士站的咖啡罐头",
                    category: "食物",
                    rarity: "rare",
                    story: "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。"
                ),
                rewardItem: RewardItem(id: "2", itemId: "item-food-001", quantity: 1, quality: .good)
            ),
            ScavengeResult(
                aiItem: AIGeneratedItem(
                    name: "急诊科常备止痛片",
                    category: "医疗",
                    rarity: "uncommon",
                    story: "瓶身上还贴着患者的名字。这是最后一个值班医生留下的，他一直到撤退前都在救治病人。"
                ),
                rewardItem: RewardItem(id: "3", itemId: "item-medical-003", quantity: 1, quality: .common)
            )
        ],
        onConfirm: {}
    )
}
