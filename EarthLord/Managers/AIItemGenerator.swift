//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成器 - 调用 Edge Function 生成搜刮物品，包含映射和降级逻辑
//

import Foundation
import Auth
import Supabase

// MARK: - 数据模型

/// AI 生成的物品（来自 Edge Function 响应）
struct AIGeneratedItem: Codable {
    let name: String        // AI 生成的独特名称
    let category: String    // 分类（医疗/食物/工具/武器/材料/水）
    let rarity: String      // 稀有度（common/uncommon/rare/epic/legendary）
    let story: String       // 背景故事
}

/// 发送到 Edge Function 的请求体
struct AIGenerateRequest: Encodable {
    let poi: POIInfo
    let itemCount: Int

    struct POIInfo: Encodable {
        let name: String
        let type: String
        let dangerLevel: Int
    }
}

/// Edge Function 响应
struct AIGenerateResponse: Codable {
    let success: Bool
    let items: [AIGeneratedItem]
    let error: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decode(Bool.self, forKey: .success)
        self.items = try container.decodeIfPresent([AIGeneratedItem].self, forKey: .items) ?? []
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    enum CodingKeys: String, CodingKey {
        case success, items, error
    }
}

/// 搜刮结果：AI 展示信息 + 库存存储信息
struct ScavengeResult: Identifiable {
    let id = UUID()
    let aiItem: AIGeneratedItem     // 用于 UI 展示（名称、故事、稀有度）
    let rewardItem: RewardItem      // 用于库存存储（映射到现有物品池）
}

// MARK: - AIItemGenerator

/// AI 物品生成器
/// 职责：调用 Edge Function 生成 AI 物品，映射到现有物品池，提供降级方案
final class AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    private init() {}

    // MARK: - Constants

    /// Edge Function URL
    private let functionURL = "https://hrtdgvplerzybnodjqmk.supabase.co/functions/v1/generate-ai-item"

    /// Supabase anon key
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhydGRndnBsZXJ6eWJub2RqcW1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5MzU1NjksImV4cCI6MjA4MzUxMTU2OX0.Zgof7wvEDEHJUOxgJO3g3Aur-4XX9TcQGkVvRhPQ1Mk"

    // MARK: - Public Methods

    /// 为 POI 生成搜刮物品（AI 优先，失败时降级）
    /// - Parameters:
    ///   - poi: 搜刮的 POI
    ///   - count: 生成物品数量
    /// - Returns: 搜刮结果列表
    func generateItems(for poi: SearchedPOI, count: Int = 3) async -> [ScavengeResult] {
        guard let aiItems = await callAI(poi: poi, count: count) else {
            print("[AIItemGenerator] AI 调用失败，使用降级方案")
            return generateFallbackItems(for: poi, count: count)
        }
        return mapToScavengeResults(aiItems)
    }

    // MARK: - Private: AI 调用

    /// 调用 Edge Function
    private func callAI(poi: SearchedPOI, count: Int) async -> [AIGeneratedItem]? {
        let request = AIGenerateRequest(
            poi: .init(
                name: poi.name,
                type: poi.type.rawValue,
                dangerLevel: poi.type.dangerLevel
            ),
            itemCount: count
        )

        do {
            let session = try await supabase.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: functionURL) else { return nil }

            var httpRequest = URLRequest(url: url)
            httpRequest.httpMethod = "POST"
            httpRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            httpRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
            httpRequest.httpBody = try JSONEncoder().encode(request)

            let (data, response) = try await URLSession.shared.data(for: httpRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[AIItemGenerator] HTTP 错误: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            let result = try JSONDecoder().decode(AIGenerateResponse.self, from: data)
            guard result.success, !result.items.isEmpty else {
                print("[AIItemGenerator] AI 返回失败: \(result.error ?? "空响应")")
                return nil
            }

            print("[AIItemGenerator] AI 成功生成 \(result.items.count) 个物品")
            return result.items

        } catch {
            print("[AIItemGenerator] 调用异常: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private: 映射逻辑

    /// AI 物品列表 → ScavengeResult 列表
    private func mapToScavengeResults(_ aiItems: [AIGeneratedItem]) -> [ScavengeResult] {
        return aiItems.map { aiItem in
            let rewardItem = RewardItem(
                id: UUID().uuidString,
                itemId: pickItemId(category: aiItem.category, rarity: aiItem.rarity),
                quantity: 1,
                quality: mapRarityToQuality(aiItem.rarity)
            )
            return ScavengeResult(aiItem: aiItem, rewardItem: rewardItem)
        }
    }

    /// 根据 AI category + rarity 选取现有物品池中匹配的 item_id
    /// 物品池内按稀有度从低到高排序，epic/legendary 倾向选取池尾
    private func pickItemId(category: String, rarity: String) -> String {
        let pool = categoryPool(for: category)
        guard !pool.isEmpty else { return "item-material-001" }

        switch rarity {
        case "legendary", "epic":
            return pool.last!
        case "rare":
            let idx = pool.count > 1 ? Int.random(in: pool.count / 2 ..< pool.count) : 0
            return pool[idx]
        default:
            return pool.randomElement()!
        }
    }

    /// 按分类返回物品池（内部按稀有度低→高排序）
    private func categoryPool(for category: String) -> [String] {
        switch category {
        case "医疗":  return ["item-medical-001", "item-medical-003", "item-medical-002"]
        case "食物":  return ["item-food-001", "item-food-002"]
        case "水":    return ["item-water-001"]
        case "工具":  return ["item-tool-002", "item-tool-001", "item-tool-003"]
        case "材料":  return ["item-material-001", "item-material-003", "item-material-002"]
        case "武器":  return ["item-tool-001", "item-tool-003"]       // 无武器物品，用工具替代
        case "服装":  return ["item-material-003", "item-material-001"] // 无服装，用材料替代
        default:     return ["item-material-001", "item-food-001", "item-water-001"]
        }
    }

    /// AI rarity → ItemQuality（用于库存存储）
    private func mapRarityToQuality(_ rarity: String) -> ItemQuality? {
        switch rarity {
        case "common":    return nil
        case "uncommon":  return .common
        case "rare":      return .good
        case "epic":      return .excellent
        case "legendary": return .epic
        default:          return nil
        }
    }

    // MARK: - Private: 降级方案（AI 不可用时）

    /// 使用预设物品库生成搜刮结果
    private func generateFallbackItems(for poi: SearchedPOI, count: Int) -> [ScavengeResult] {
        let dangerLevel = poi.type.dangerLevel

        return (0..<count).map { _ in
            let itemId = rollFallbackItem(dangerLevel: dangerLevel)
            let rarity = rollFallbackRarity(dangerLevel: dangerLevel)
            let definition = MockExplorationData.getItemDefinition(by: itemId)

            let fallbackAI = AIGeneratedItem(
                name: definition?.name ?? "废弃物品",
                category: definition?.category.rawValue ?? "材料",
                rarity: rarity,
                story: definition?.description ?? "末日世界中残留的物品。"
            )

            let rewardItem = RewardItem(
                id: UUID().uuidString,
                itemId: itemId,
                quantity: 1,
                quality: definition?.hasQuality == true ? mapRarityToQuality(rarity) : nil
            )

            return ScavengeResult(aiItem: fallbackAI, rewardItem: rewardItem)
        }
    }

    /// 降级：按危险值和概率分布选取物品
    private func rollFallbackItem(dangerLevel: Int) -> String {
        let random = Double.random(in: 0..<1)
        let commonPool = ["item-water-001", "item-food-001", "item-medical-001", "item-material-001", "item-material-003", "item-tool-002"]
        let rarePool   = ["item-food-002", "item-medical-003", "item-material-002", "item-tool-001"]
        let epicPool   = ["item-medical-002", "item-tool-003"]

        switch dangerLevel {
        case 1, 2:
            return random < 0.90 ? commonPool.randomElement()! : rarePool.randomElement()!
        case 3:
            if random < 0.50       { return commonPool.randomElement()! }
            else if random < 0.85  { return rarePool.randomElement()! }
            else                   { return epicPool.randomElement()! }
        case 4:
            if random < 0.40       { return rarePool.randomElement()! }
            else                   { return epicPool.randomElement()! }
        default: // 5
            return epicPool.randomElement()!
        }
    }

    /// 降级：按危险值返回 rarity 字符串
    private func rollFallbackRarity(dangerLevel: Int) -> String {
        let random = Double.random(in: 0..<1)
        switch dangerLevel {
        case 1, 2:
            if random < 0.70       { return "common" }
            else if random < 0.95  { return "uncommon" }
            else                   { return "rare" }
        case 3:
            if random < 0.50       { return "common" }
            else if random < 0.80  { return "uncommon" }
            else if random < 0.95  { return "rare" }
            else                   { return "epic" }
        case 4:
            if random < 0.40       { return "uncommon" }
            else if random < 0.75  { return "rare" }
            else if random < 0.95  { return "epic" }
            else                   { return "legendary" }
        default: // 5
            if random < 0.30       { return "rare" }
            else if random < 0.70  { return "epic" }
            else                   { return "legendary" }
        }
    }
}
