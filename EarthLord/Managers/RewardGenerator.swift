//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器 - 根据行走距离生成物品奖励
//

import Foundation

/// 奖励等级
enum RewardTier: String, Codable {
    case none = "none"         // 无奖励 (0-200米)
    case bronze = "bronze"     // 铜级 (200-500米)
    case silver = "silver"     // 银级 (500-1000米)
    case gold = "gold"         // 金级 (1000-2000米)
    case diamond = "diamond"   // 钻石级 (2000米以上)

    /// 等级显示名称
    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "🥉 铜级"
        case .silver: return "🥈 银级"
        case .gold: return "🥇 金级"
        case .diamond: return "💎 钻石级"
        }
    }

    /// 等级描述
    var description: String {
        switch self {
        case .none: return "探索距离不足"
        case .bronze: return "小试牛刀"
        case .silver: return "探索有成"
        case .gold: return "勇往直前"
        case .diamond: return "探索大师"
        }
    }
}

/// 物品稀有度（用于奖励生成）
enum ItemRarityTier: Int, CaseIterable {
    case common = 1     // 普通
    case rare = 3       // 稀有
    case epic = 4       // 史诗

    /// 对应的ItemRarity值
    var toItemRarity: ItemRarity {
        switch self {
        case .common: return .common
        case .rare: return .rare
        case .epic: return .veryRare
        }
    }
}

/// 奖励配置
struct RewardConfig {
    let itemCount: Int                      // 物品数量
    let rarityProbabilities: [ItemRarityTier: Double]  // 稀有度概率

    /// 铜级配置
    static let bronze = RewardConfig(
        itemCount: 1,
        rarityProbabilities: [
            .common: 0.90,  // 90%
            .rare: 0.10,    // 10%
            .epic: 0.00     // 0%
        ]
    )

    /// 银级配置
    static let silver = RewardConfig(
        itemCount: 2,
        rarityProbabilities: [
            .common: 0.70,  // 70%
            .rare: 0.25,    // 25%
            .epic: 0.05     // 5%
        ]
    )

    /// 金级配置
    static let gold = RewardConfig(
        itemCount: 3,
        rarityProbabilities: [
            .common: 0.50,  // 50%
            .rare: 0.35,    // 35%
            .epic: 0.15     // 15%
        ]
    )

    /// 钻石级配置
    static let diamond = RewardConfig(
        itemCount: 5,
        rarityProbabilities: [
            .common: 0.30,  // 30%
            .rare: 0.40,    // 40%
            .epic: 0.30     // 30%
        ]
    )
}

/// 奖励生成器
class RewardGenerator {

    // MARK: - Singleton

    static let shared = RewardGenerator()

    private init() {}

    // MARK: - Item Pools

    /// 普通物品池
    private let commonItemPool: [String] = [
        "item-water-001",      // 矿泉水
        "item-food-001",       // 罐头食品
        "item-medical-001",    // 绷带
        "item-material-001",   // 木材
        "item-material-003",   // 塑料碎片
        "item-tool-002"        // 绳子
    ]

    /// 稀有物品池
    private let rareItemPool: [String] = [
        "item-food-002",       // 压缩饼干
        "item-medical-003",    // 止痛药
        "item-material-002",   // 废金属
        "item-tool-001"        // 手电筒
    ]

    /// 史诗物品池
    private let epicItemPool: [String] = [
        "item-medical-002",    // 抗生素
        "item-tool-003"        // 多功能刀
    ]

    // MARK: - Public Methods

    /// 根据距离生成奖励
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级和物品列表
    func generateReward(for distance: Double) -> (tier: RewardTier, items: [RewardItem]) {
        // 1. 确定奖励等级
        let tier = calculateTier(for: distance)

        // 2. 如果无奖励，直接返回
        guard tier != .none else {
            return (tier, [])
        }

        // 3. 获取奖励配置
        let config = getConfig(for: tier)

        // 4. 生成物品
        let items = generateItems(count: config.itemCount, probabilities: config.rarityProbabilities)

        print("🎁 生成奖励 - 等级: \(tier.displayName), 物品数: \(items.count)")
        for item in items {
            print("  - \(item.itemId) x\(item.quantity)")
        }

        return (tier, items)
    }

    /// 计算奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级
    func calculateTier(for distance: Double) -> RewardTier {
        if distance < 200 {
            return .none
        } else if distance < 500 {
            return .bronze
        } else if distance < 1000 {
            return .silver
        } else if distance < 2000 {
            return .gold
        } else {
            return .diamond
        }
    }

    // MARK: - Private Methods

    /// 获取等级对应的配置
    private func getConfig(for tier: RewardTier) -> RewardConfig {
        switch tier {
        case .none:
            return RewardConfig(itemCount: 0, rarityProbabilities: [:])
        case .bronze:
            return .bronze
        case .silver:
            return .silver
        case .gold:
            return .gold
        case .diamond:
            return .diamond
        }
    }

    /// 生成物品列表
    private func generateItems(count: Int, probabilities: [ItemRarityTier: Double]) -> [RewardItem] {
        var items: [RewardItem] = []

        for _ in 0..<count {
            // 1. 掷骰子决定稀有度
            let rarityTier = rollRarity(probabilities: probabilities)

            // 2. 从对应物品池随机抽取
            guard let itemId = randomItem(from: rarityTier) else {
                continue
            }

            // 3. 决定数量
            let quantity = randomQuantity(for: rarityTier)

            // 4. 决定品质（部分物品有品质）
            let quality = shouldHaveQuality(itemId: itemId) ? randomQuality() : nil

            // 5. 创建奖励物品
            let rewardItem = RewardItem(
                id: UUID().uuidString,
                itemId: itemId,
                quantity: quantity,
                quality: quality
            )

            items.append(rewardItem)
        }

        return items
    }

    /// 掷骰子决定稀有度
    private func rollRarity(probabilities: [ItemRarityTier: Double]) -> ItemRarityTier {
        let random = Double.random(in: 0..<1.0)
        var cumulative: Double = 0

        for (tier, probability) in probabilities.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            cumulative += probability
            if random < cumulative {
                return tier
            }
        }

        // 默认返回普通
        return .common
    }

    /// 从物品池中随机抽取
    private func randomItem(from tier: ItemRarityTier) -> String? {
        let pool: [String]
        switch tier {
        case .common:
            pool = commonItemPool
        case .rare:
            pool = rareItemPool
        case .epic:
            pool = epicItemPool
        }

        return pool.randomElement()
    }

    /// 随机生成物品数量
    private func randomQuantity(for tier: ItemRarityTier) -> Int {
        switch tier {
        case .common:
            return Int.random(in: 2...5)
        case .rare:
            return Int.random(in: 1...3)
        case .epic:
            return 1
        }
    }

    /// 判断物品是否有品质
    private func shouldHaveQuality(itemId: String) -> Bool {
        // 医疗类和工具类物品有品质
        return itemId.contains("medical") || itemId.contains("tool")
    }

    /// 随机生成物品品质
    private func randomQuality() -> ItemQuality {
        let random = Double.random(in: 0..<1.0)

        if random < 0.60 {
            return .common      // 60%
        } else if random < 0.85 {
            return .good        // 25%
        } else if random < 0.97 {
            return .excellent   // 12%
        } else {
            return .epic        // 3%
        }
    }
}

// MARK: - RewardItem

/// 奖励物品
struct RewardItem: Identifiable, Codable {
    let id: String
    let itemId: String
    let quantity: Int
    let quality: ItemQuality?
}
