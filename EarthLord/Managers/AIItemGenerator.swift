//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成器 - 直接调用 DashScope API 生成搜刮物品，包含映射和降级逻辑
//

import Foundation

// MARK: - 数据模型

/// AI 生成的物品
struct AIGeneratedItem: Codable {
    let name: String        // AI 生成的独特名称
    let category: String    // 分类（医疗/食物/工具/武器/材料/水）
    let rarity: String      // 稀有度（common/uncommon/rare/epic/legendary）
    let story: String       // 背景故事
}

/// DashScope API 请求体
struct DashScopeRequest: Encodable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let temperature: Double

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

/// DashScope API 响应
struct DashScopeResponse: Decodable {
    let choices: [Choice]?
    let error: ErrorInfo?

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }

    struct ErrorInfo: Decodable {
        let message: String
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
/// 职责：直接调用 DashScope API 生成 AI 物品，映射到现有物品池，提供降级方案
final class AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    private init() {}

    // MARK: - Constants

    /// DashScope API URL（阿里云通义千问，OpenAI 兼容接口）
    private let apiURL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions"

    /// DashScope API Key（⚠️ 生产环境应从安全存储获取）
    private let apiKey = "sk-1eaef36929b94b6883e8e009bedfc7f4"

    /// 系统提示词
    private let systemPrompt = """
        你是一个末日生存游戏的物品生成器。游戏背景是丧尸末日后的世界。

        根据搜刮地点生成物品列表，每个物品必须包含以下字段：
        - name: 独特名称（15字以内），暗示前主人或物品来历
        - category: 分类，只能从以下选择：医疗、食物、工具、武器、材料、水
        - rarity: 稀有度，只能从以下选择：common、uncommon、rare、epic、legendary
        - story: 背景故事（50-100字），营造末日氛围

        规则：
        1. 物品类型要与地点紧密相关（医院出医疗物品，便利店出食物和水）
        2. 名称要有创意和画面感
        3. 故事要简短有画面感，可以有黑色幽默
        4. 稀有度越高，名称和故事越独特精彩
        5. 严格按照用户提示中的稀有度分布比例生成

        只返回 JSON 数组，不要其他任何内容。
        """

    // MARK: - Public Methods

    /// 为 POI 生成搜刮物品（AI 优先，失败时降级）
    /// - Parameters:
    ///   - poi: 搜刮的 POI
    ///   - count: 生成物品数量
    /// - Returns: 搜刮结果列表
    func generateItems(for poi: SearchedPOI, count: Int = 3) async -> [ScavengeResult] {
        guard let aiItems = await callDashScopeAPI(poi: poi, count: count) else {
            print("[AIItemGenerator] AI 调用失败，使用降级方案")
            return generateFallbackItems(for: poi, count: count)
        }
        return mapToScavengeResults(aiItems)
    }

    // MARK: - Private: 直接调用 DashScope API

    /// 直接调用 DashScope API（通义千问）
    private func callDashScopeAPI(poi: SearchedPOI, count: Int) async -> [AIGeneratedItem]? {
        let dangerLevel = poi.type.dangerLevel
        let weights = getRarityWeights(dangerLevel: dangerLevel)

        let userPrompt = """
            搜刮地点：\(poi.name)（\(poi.type.rawValue)类型，危险等级 \(dangerLevel)/5）

            请生成 \(count) 个物品。严格参考以下稀有度分布比例：
            \(weights.filter { $0.value > 0 }.map { "- \($0.key): \($0.value)%" }.joined(separator: "\n"))

            返回 JSON 数组，每个元素包含 name、category、rarity、story 字段。只返回数组，不要其他内容。
            """

        let request = DashScopeRequest(
            model: "qwen-flash",
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            max_tokens: 800,
            temperature: 0.8
        )

        do {
            guard let url = URL(string: apiURL) else { return nil }

            var httpRequest = URLRequest(url: url)
            httpRequest.httpMethod = "POST"
            httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            httpRequest.httpBody = try JSONEncoder().encode(request)

            let (data, response) = try await URLSession.shared.data(for: httpRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[AIItemGenerator] 无效响应")
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                print("[AIItemGenerator] HTTP 错误: \(httpResponse.statusCode)")
                if let errorText = String(data: data, encoding: .utf8) {
                    print("[AIItemGenerator] 错误详情: \(errorText)")
                }
                return nil
            }

            let result = try JSONDecoder().decode(DashScopeResponse.self, from: data)

            guard let content = result.choices?.first?.message.content else {
                print("[AIItemGenerator] AI 返回空内容")
                return nil
            }

            // 提取 JSON（处理可能的 markdown 代码块包裹）
            let jsonString = extractJSON(from: content)
            guard let jsonData = jsonString.data(using: .utf8) else { return nil }

            let items = try JSONDecoder().decode([AIGeneratedItem].self, from: jsonData)
            print("[AIItemGenerator] AI 成功生成 \(items.count) 个物品")
            return items

        } catch {
            print("[AIItemGenerator] 调用异常: \(error.localizedDescription)")
            return nil
        }
    }

    /// 根据危险等级获取稀有度权重
    private func getRarityWeights(dangerLevel: Int) -> [String: Int] {
        switch dangerLevel {
        case 1, 2:
            return ["common": 70, "uncommon": 25, "rare": 5, "epic": 0, "legendary": 0]
        case 3:
            return ["common": 50, "uncommon": 30, "rare": 15, "epic": 5, "legendary": 0]
        case 4:
            return ["common": 0, "uncommon": 40, "rare": 35, "epic": 20, "legendary": 5]
        case 5:
            return ["common": 0, "uncommon": 0, "rare": 30, "epic": 40, "legendary": 30]
        default:
            return ["common": 60, "uncommon": 30, "rare": 10, "epic": 0, "legendary": 0]
        }
    }

    /// 提取 AI 返回的 JSON（处理可能的 markdown 代码块包裹）
    private func extractJSON(from text: String) -> String {
        // 尝试匹配 ```json ... ``` 或 ``` ... ```
        let pattern = "```(?:json)?\\s*([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
