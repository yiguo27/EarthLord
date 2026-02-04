//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器 - 负责管理玩家背包数据，与数据库同步
//

import Foundation
import Supabase
import Combine

/// 数据库中的背包物品（与inventory_items表对应）
struct DBInventoryItem: Codable {
    let id: String
    let userId: String
    let itemId: String
    var quantity: Int
    let quality: String?
    let obtainedAt: Date
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case obtainedAt = "obtained_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 转换为UI使用的BackpackItem
    func toBackpackItem() -> BackpackItem {
        let itemQuality: ItemQuality? = quality != nil ? ItemQuality(rawValue: quality!) : nil

        return BackpackItem(
            id: id,
            itemId: itemId,
            quantity: quantity,
            quality: itemQuality,
            obtainedAt: obtainedAt
        )
    }
}

/// 背包管理器
class InventoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = InventoryManager()

    // MARK: - Published Properties

    /// 背包物品列表
    @Published var items: [BackpackItem] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Constants

    /// 最大背包容量（槽位数）
    let maxCapacity: Int = 100

    /// 每个槽位最大堆叠数
    let maxStackSize: Int = 99

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 加载背包数据
    func loadInventory() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // 获取当前用户ID
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString

            print("📦 加载背包数据 - 用户ID: \(userId)")

            // 从数据库查询背包物品
            let response: [DBInventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            print("📦 查询到 \(response.count) 个物品")

            // 转换为BackpackItem
            let backpackItems = response.map { $0.toBackpackItem() }

            await MainActor.run {
                self.items = backpackItems
                self.isLoading = false
            }

        } catch {
            print("❌ 加载背包失败: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "加载背包失败: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// 添加物品到背包
    /// - Parameter rewards: 奖励物品列表
    func addItems(_ rewards: [RewardItem]) async throws {
        guard !rewards.isEmpty else { return }

        // 获取当前用户ID
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        print("📦 添加物品到背包 - 用户ID: \(userId), 物品数: \(rewards.count)")

        for reward in rewards {
            try await addItem(
                userId: userId,
                itemId: reward.itemId,
                quantity: reward.quantity,
                quality: reward.quality
            )
        }

        // 重新加载背包
        await loadInventory()
    }

    /// 添加单个物品（内部方法）
    private func addItem(userId: String, itemId: String, quantity: Int, quality: ItemQuality?) async throws {
        // 1. 检查是否已存在相同物品（同item_id, 同quality）
        let qualityStr = quality?.rawValue

        // 查询现有物品
        let existingItems: [DBInventoryItem]
        if let qualityStr = qualityStr {
            existingItems = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId)
                .eq("item_id", value: itemId)
                .eq("quality", value: qualityStr)
                .execute()
                .value
        } else {
            existingItems = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId)
                .eq("item_id", value: itemId)
                .is("quality", value: nil)
                .execute()
                .value
        }

        if let existingItem = existingItems.first {
            // 2. 如果存在，更新数量
            let newQuantity = existingItem.quantity + quantity

            print("📦 更新物品数量: \(itemId) (\(existingItem.quantity) + \(quantity) = \(newQuantity))")

            struct UpdateData: Encodable {
                let quantity: Int
                let updated_at: String
            }
            let updateData = UpdateData(quantity: newQuantity, updated_at: ISO8601DateFormatter().string(from: Date()))

            try await supabase
                .from("inventory_items")
                .update(updateData)
                .eq("id", value: existingItem.id)
                .execute()

        } else {
            // 3. 如果不存在，创建新记录
            print("📦 创建新物品: \(itemId) x\(quantity)")

            struct NewItem: Encodable {
                let user_id: String
                let item_id: String
                let quantity: Int
                let quality: String?
                let obtained_at: String
            }
            let newItem = NewItem(
                user_id: userId,
                item_id: itemId,
                quantity: quantity,
                quality: qualityStr,
                obtained_at: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase
                .from("inventory_items")
                .insert(newItem)
                .execute()
        }
    }

    /// 移除物品
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quantity: 数量
    func removeItem(itemId: String, quantity: Int) async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        // 查询物品
        let existingItems: [DBInventoryItem] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .eq("item_id", value: itemId)
            .execute()
            .value

        guard let item = existingItems.first else {
            throw InventoryError.itemNotFound
        }

        if item.quantity <= quantity {
            // 删除整个记录
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("id", value: item.id)
                .execute()
        } else {
            // 减少数量
            let newQuantity = item.quantity - quantity
            struct UpdateData: Encodable {
                let quantity: Int
                let updated_at: String
            }
            let updateData = UpdateData(quantity: newQuantity, updated_at: ISO8601DateFormatter().string(from: Date()))
            try await supabase
                .from("inventory_items")
                .update(updateData)
                .eq("id", value: item.id)
                .execute()
        }

        // 重新加载
        await loadInventory()
    }

    /// 获取当前背包容量
    func getCurrentCapacity() -> Int {
        // 计算总重量或使用物品种类数
        // 这里简化为物品种类数 × 平均重量系数
        return min(items.count * 7, maxCapacity)
    }

    /// 检查背包是否已满
    func isFull() -> Bool {
        return items.count >= maxCapacity
    }
}

// MARK: - InventoryError

enum InventoryError: LocalizedError {
    case userNotAuthenticated
    case itemNotFound
    case capacityFull

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "用户未登录"
        case .itemNotFound:
            return "物品不存在"
        case .capacityFull:
            return "背包已满"
        }
    }
}
