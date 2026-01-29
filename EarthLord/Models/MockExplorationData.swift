//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块的测试假数据
//  包含：POI列表、背包物品、物品定义表、探索结果示例
//

import Foundation
import CoreLocation

// MARK: - POI（兴趣点）数据模型

/// POI 状态
enum POIStatus: String, Codable {
    case undiscovered = "未发现"  // 未发现
    case discovered = "已发现"    // 已发现
    case looted = "已搜空"        // 已被搜空
}

/// POI 类型
enum POIType: String, Codable {
    case supermarket = "超市"
    case hospital = "医院"
    case gasStation = "加油站"
    case pharmacy = "药店"
    case factory = "工厂"
    case warehouse = "仓库"
    case school = "学校"
    case mall = "商场"
}

/// 兴趣点数据结构
struct POI: Identifiable, Codable {
    let id: String
    let name: String                      // 名称（如：废弃超市）
    let type: POIType                     // 类型
    let coordinate: Coordinate            // 坐标
    var status: POIStatus                 // 状态
    let hasResources: Bool                // 是否有物资
    let description: String               // 描述
    let distanceFromUser: Double?         // 距离用户的距离（米）

    /// 简单的坐标结构（用于 Codable）
    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double

        func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
}

// MARK: - 物品数据模型

/// 物品类别
enum ItemCategory: String, Codable {
    case water = "水"           // 水类
    case food = "食物"          // 食物
    case medical = "医疗"       // 医疗用品
    case material = "材料"      // 建筑材料
    case tool = "工具"          // 工具
    case weapon = "武器"        // 武器
    case clothing = "服装"      // 服装
}

/// 物品品质
enum ItemQuality: String, Codable {
    case common = "普通"        // 普通品质
    case good = "良好"          // 良好品质
    case excellent = "优秀"     // 优秀品质
    case epic = "史诗"          // 史诗品质

    /// 品质对应的颜色（用于UI显示）
    var colorHex: String {
        switch self {
        case .common: return "#808080"      // 灰色
        case .good: return "#00FF00"        // 绿色
        case .excellent: return "#0080FF"   // 蓝色
        case .epic: return "#800080"        // 紫色
        }
    }
}

/// 物品稀有度
enum ItemRarity: Int, Codable {
    case common = 1         // 常见
    case uncommon = 2       // 不常见
    case rare = 3           // 稀有
    case veryRare = 4       // 非常稀有
    case legendary = 5      // 传说

    var displayName: String {
        switch self {
        case .common: return "常见"
        case .uncommon: return "不常见"
        case .rare: return "稀有"
        case .veryRare: return "非常稀有"
        case .legendary: return "传说"
        }
    }
}

/// 背包物品（用户拥有的物品实例）
struct BackpackItem: Identifiable, Codable {
    let id: String
    let itemId: String                // 物品定义ID（关联 ItemDefinition）
    var quantity: Int                 // 数量
    let quality: ItemQuality?         // 品质（部分物品没有品质，如材料）
    let obtainedAt: Date              // 获得时间
}

/// 物品定义（物品的基础属性）
struct ItemDefinition: Identifiable, Codable {
    let id: String
    let name: String                  // 中文名称
    let category: ItemCategory        // 分类
    let weight: Double                // 单个重量（kg）
    let volume: Double                // 单个体积（立方米）
    let rarity: ItemRarity            // 稀有度
    let description: String           // 描述
    let iconName: String              // 图标名称（SF Symbol）
    let hasQuality: Bool              // 是否有品质属性
    let stackable: Bool               // 是否可堆叠
    let maxStack: Int                 // 最大堆叠数量
}

// MARK: - 探索结果数据模型

/// 探索结果统计
struct ExplorationResult: Codable {
    // 本次探索数据
    let sessionDistance: Double           // 本次行走距离（米）
    let sessionArea: Double               // 本次探索面积（平方米）
    let sessionDuration: TimeInterval     // 本次探索时长（秒）
    let sessionItemsFound: [ItemReward]   // 本次获得的物品

    // 累计数据
    let totalDistance: Double             // 累计行走距离（米）
    let totalArea: Double                 // 累计探索面积（平方米）

    // 排名数据
    let distanceRank: Int                 // 行走距离排名
    let areaRank: Int                     // 探索面积排名
}

/// 物品奖励
struct ItemReward: Identifiable, Codable {
    let id: String
    let itemId: String                    // 物品定义ID
    let quantity: Int                     // 数量
    let quality: ItemQuality?             // 品质
}

// MARK: - 测试假数据

/// 探索模块测试假数据
struct MockExplorationData {

    // MARK: - 1. POI 列表测试数据

    /// 测试用的 POI 列表（5个不同状态的兴趣点）
    static let mockPOIs: [POI] = [
        // 1. 废弃超市 - 已发现，有物资
        POI(
            id: "poi-001",
            name: "废弃超市",
            type: .supermarket,
            coordinate: POI.Coordinate(latitude: 39.9042, longitude: 116.4074),
            status: .discovered,
            hasResources: true,
            description: "一座废弃的大型超市，货架倒塌，但仍可能找到食物和水。",
            distanceFromUser: 150.0
        ),

        // 2. 医院废墟 - 已发现，已被搜空
        POI(
            id: "poi-002",
            name: "医院废墟",
            type: .hospital,
            coordinate: POI.Coordinate(latitude: 39.9052, longitude: 116.4084),
            status: .looted,
            hasResources: false,
            description: "一座被洗劫一空的医院废墟，医疗物资已被搜空。",
            distanceFromUser: 320.0
        ),

        // 3. 加油站 - 未发现
        POI(
            id: "poi-003",
            name: "废弃加油站",
            type: .gasStation,
            coordinate: POI.Coordinate(latitude: 39.9062, longitude: 116.4094),
            status: .undiscovered,
            hasResources: true,
            description: "一座废弃的加油站，可能有燃料和工具。",
            distanceFromUser: 580.0
        ),

        // 4. 药店废墟 - 已发现，有物资
        POI(
            id: "poi-004",
            name: "药店废墟",
            type: .pharmacy,
            coordinate: POI.Coordinate(latitude: 39.9032, longitude: 116.4064),
            status: .discovered,
            hasResources: true,
            description: "一座小型药店的废墟，可能还有剩余的药品。",
            distanceFromUser: 420.0
        ),

        // 5. 工厂废墟 - 未发现
        POI(
            id: "poi-005",
            name: "工厂废墟",
            type: .factory,
            coordinate: POI.Coordinate(latitude: 39.9072, longitude: 116.4104),
            status: .undiscovered,
            hasResources: true,
            description: "一座废弃的工厂，可能有金属材料和工具。",
            distanceFromUser: 890.0
        )
    ]

    // MARK: - 2. 物品定义表（所有可能的物品）

    /// 所有物品的定义数据
    static let itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "item-water-001",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.0005,
            rarity: .common,
            description: "一瓶500ml的矿泉水，生存的基本需求。",
            iconName: "drop.fill",
            hasQuality: false,
            stackable: true,
            maxStack: 20
        ),

        // 食物类
        ItemDefinition(
            id: "item-food-001",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.0003,
            rarity: .common,
            description: "密封的罐头食品，可以长期保存。",
            iconName: "cube.box.fill",
            hasQuality: false,
            stackable: true,
            maxStack: 15
        ),

        ItemDefinition(
            id: "item-food-002",
            name: "压缩饼干",
            category: .food,
            weight: 0.2,
            volume: 0.0001,
            rarity: .uncommon,
            description: "高热量的压缩饼干，便于携带。",
            iconName: "square.stack.fill",
            hasQuality: false,
            stackable: true,
            maxStack: 30
        ),

        // 医疗类
        ItemDefinition(
            id: "item-medical-001",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.00005,
            rarity: .common,
            description: "用于包扎伤口的医用绷带。",
            iconName: "bandage.fill",
            hasQuality: true,
            stackable: true,
            maxStack: 50
        ),

        ItemDefinition(
            id: "item-medical-002",
            name: "抗生素",
            category: .medical,
            weight: 0.02,
            volume: 0.00002,
            rarity: .rare,
            description: "珍贵的抗生素药品，可以治疗感染。",
            iconName: "cross.case.fill",
            hasQuality: true,
            stackable: true,
            maxStack: 10
        ),

        ItemDefinition(
            id: "item-medical-003",
            name: "止痛药",
            category: .medical,
            weight: 0.01,
            volume: 0.00001,
            rarity: .uncommon,
            description: "用于缓解疼痛的药品。",
            iconName: "pills.fill",
            hasQuality: true,
            stackable: true,
            maxStack: 20
        ),

        // 材料类
        ItemDefinition(
            id: "item-material-001",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 0.005,
            rarity: .common,
            description: "可用于建造和修复的木材。",
            iconName: "square.fill.on.square.fill",
            hasQuality: false,
            stackable: true,
            maxStack: 50
        ),

        ItemDefinition(
            id: "item-material-002",
            name: "废金属",
            category: .material,
            weight: 3.0,
            volume: 0.003,
            rarity: .uncommon,
            description: "废弃的金属材料，可以回收利用。",
            iconName: "cube.fill",
            hasQuality: false,
            stackable: true,
            maxStack: 30
        ),

        ItemDefinition(
            id: "item-material-003",
            name: "塑料碎片",
            category: .material,
            weight: 0.3,
            volume: 0.001,
            rarity: .common,
            description: "各种塑料碎片，可能有用。",
            iconName: "triangle.fill",
            hasQuality: false,
            stackable: true,
            maxStack: 100
        ),

        // 工具类
        ItemDefinition(
            id: "item-tool-001",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.0002,
            rarity: .uncommon,
            description: "LED手电筒，夜间探索必备。",
            iconName: "flashlight.on.fill",
            hasQuality: true,
            stackable: false,
            maxStack: 1
        ),

        ItemDefinition(
            id: "item-tool-002",
            name: "绳子",
            category: .tool,
            weight: 0.5,
            volume: 0.001,
            rarity: .common,
            description: "10米长的尼龙绳，用途广泛。",
            iconName: "link",
            hasQuality: false,
            stackable: true,
            maxStack: 5
        ),

        ItemDefinition(
            id: "item-tool-003",
            name: "多功能刀",
            category: .tool,
            weight: 0.15,
            volume: 0.00008,
            rarity: .rare,
            description: "带有多种功能的瑞士军刀。",
            iconName: "scissors",
            hasQuality: true,
            stackable: false,
            maxStack: 1
        )
    ]

    // MARK: - 3. 背包物品测试数据（用户当前拥有的物品）

    /// 测试用的背包物品（6-8种不同类型）
    static let mockBackpackItems: [BackpackItem] = [
        // 1. 矿泉水 x3
        BackpackItem(
            id: "backpack-001",
            itemId: "item-water-001",
            quantity: 3,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600 * 24) // 1天前获得
        ),

        // 2. 罐头食品 x5
        BackpackItem(
            id: "backpack-002",
            itemId: "item-food-001",
            quantity: 5,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600 * 48) // 2天前获得
        ),

        // 3. 压缩饼干 x2
        BackpackItem(
            id: "backpack-003",
            itemId: "item-food-002",
            quantity: 2,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600 * 12) // 12小时前获得
        ),

        // 4. 绷带（良好品质）x8
        BackpackItem(
            id: "backpack-004",
            itemId: "item-medical-001",
            quantity: 8,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-3600 * 36) // 1.5天前获得
        ),

        // 5. 抗生素（优秀品质）x2
        BackpackItem(
            id: "backpack-005",
            itemId: "item-medical-002",
            quantity: 2,
            quality: .excellent,
            obtainedAt: Date().addingTimeInterval(-3600 * 72) // 3天前获得
        ),

        // 6. 木材 x15
        BackpackItem(
            id: "backpack-006",
            itemId: "item-material-001",
            quantity: 15,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600 * 6) // 6小时前获得
        ),

        // 7. 废金属 x8
        BackpackItem(
            id: "backpack-007",
            itemId: "item-material-002",
            quantity: 8,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600 * 24) // 1天前获得
        ),

        // 8. 手电筒（史诗品质）x1
        BackpackItem(
            id: "backpack-008",
            itemId: "item-tool-001",
            quantity: 1,
            quality: .epic,
            obtainedAt: Date().addingTimeInterval(-3600 * 120) // 5天前获得
        ),

        // 9. 绳子 x2
        BackpackItem(
            id: "backpack-009",
            itemId: "item-tool-002",
            quantity: 2,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600 * 18) // 18小时前获得
        )
    ]

    // MARK: - 4. 探索结果示例

    /// 测试用的探索结果数据
    static let mockExplorationResult = ExplorationResult(
        // 本次探索数据
        sessionDistance: 2500.0,          // 本次行走 2500 米
        sessionArea: 50000.0,             // 本次探索 5万 平方米
        sessionDuration: 1800.0,          // 本次探索 30 分钟（1800秒）
        sessionItemsFound: [
            ItemReward(id: "reward-001", itemId: "item-material-001", quantity: 5, quality: nil),     // 木材 x5
            ItemReward(id: "reward-002", itemId: "item-water-001", quantity: 3, quality: nil),        // 矿泉水 x3
            ItemReward(id: "reward-003", itemId: "item-food-001", quantity: 2, quality: nil),         // 罐头 x2
            ItemReward(id: "reward-004", itemId: "item-medical-001", quantity: 3, quality: .good),    // 绷带 x3（良好）
            ItemReward(id: "reward-005", itemId: "item-material-002", quantity: 2, quality: nil)      // 废金属 x2
        ],

        // 累计数据
        totalDistance: 15000.0,           // 累计行走 15000 米
        totalArea: 250000.0,              // 累计探索 25万 平方米

        // 排名数据
        distanceRank: 42,                 // 行走距离排名第 42 名
        areaRank: 38                      // 探索面积排名第 38 名
    )

    // MARK: - 辅助方法

    /// 根据物品ID获取物品定义
    static func getItemDefinition(by itemId: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == itemId }
    }

    /// 根据物品ID获取物品名称
    static func getItemName(by itemId: String) -> String {
        return getItemDefinition(by: itemId)?.name ?? "未知物品"
    }

    /// 计算背包总重量
    static func calculateTotalWeight(items: [BackpackItem]) -> Double {
        var totalWeight = 0.0
        for item in items {
            if let definition = getItemDefinition(by: item.itemId) {
                totalWeight += definition.weight * Double(item.quantity)
            }
        }
        return totalWeight
    }

    /// 计算背包总体积
    static func calculateTotalVolume(items: [BackpackItem]) -> Double {
        var totalVolume = 0.0
        for item in items {
            if let definition = getItemDefinition(by: item.itemId) {
                totalVolume += definition.volume * Double(item.quantity)
            }
        }
        return totalVolume
    }

    /// 按类别分组背包物品
    static func groupItemsByCategory(items: [BackpackItem]) -> [ItemCategory: [BackpackItem]] {
        var grouped: [ItemCategory: [BackpackItem]] = [:]

        for item in items {
            if let definition = getItemDefinition(by: item.itemId) {
                if grouped[definition.category] == nil {
                    grouped[definition.category] = []
                }
                grouped[definition.category]?.append(item)
            }
        }

        return grouped
    }

    /// 格式化距离显示
    static func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return String(format: "%.0f 米", distance)
        } else {
            return String(format: "%.1f 公里", distance / 1000.0)
        }
    }

    /// 格式化面积显示
    static func formatArea(_ area: Double) -> String {
        if area < 10000 {
            return String(format: "%.0f 平方米", area)
        } else {
            return String(format: "%.1f 万平方米", area / 10000.0)
        }
    }

    /// 格式化时长显示
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return String(format: "%d 小时 %d 分钟", hours, minutes)
        } else {
            return String(format: "%d 分钟", minutes)
        }
    }
}

// MARK: - Preview 辅助

#if DEBUG
extension MockExplorationData {
    /// 打印所有测试数据（用于调试）
    static func printAllMockData() {
        print("\n========== 探索模块测试数据 ==========\n")

        print("📍 POI 列表：")
        for poi in mockPOIs {
            print("  - \(poi.name)（\(poi.type.rawValue)）: \(poi.status.rawValue)")
            if poi.hasResources {
                print("    ✅ 有物资")
            } else {
                print("    ❌ 无物资")
            }
        }

        print("\n🎒 背包物品：")
        for item in mockBackpackItems {
            if let def = getItemDefinition(by: item.itemId) {
                let qualityStr = item.quality?.rawValue ?? "无"
                print("  - \(def.name) x\(item.quantity)（品质：\(qualityStr)）")
            }
        }

        print("\n📦 物品定义表（\(itemDefinitions.count) 种物品）：")
        for def in itemDefinitions {
            print("  - \(def.name)（\(def.category.rawValue)）: \(def.rarity.displayName)")
        }

        print("\n🗺️ 探索结果：")
        let result = mockExplorationResult
        print("  本次行走: \(formatDistance(result.sessionDistance))")
        print("  本次面积: \(formatArea(result.sessionArea))")
        print("  本次时长: \(formatDuration(result.sessionDuration))")
        print("  累计行走: \(formatDistance(result.totalDistance))（排名 #\(result.distanceRank)）")
        print("  累计面积: \(formatArea(result.totalArea))（排名 #\(result.areaRank)）")
        print("  获得物品:")
        for reward in result.sessionItemsFound {
            print("    - \(getItemName(by: reward.itemId)) x\(reward.quantity)")
        }

        print("\n========================================\n")
    }
}
#endif
