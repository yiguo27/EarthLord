//
//  StatsManager.swift
//  EarthLord
//
//  统计数据管理器 - 实时查询和更新用户统计数据
//

import Foundation
import Combine
import Supabase
import CoreLocation

@MainActor
final class StatsManager: ObservableObject {
    static let shared = StatsManager()

    // MARK: - Published 属性

    /// 领地数量
    @Published var territoryCount: Int = 0

    /// 资源点数量
    @Published var resourcePointCount: Int = 0

    /// 探索距离（公里）
    @Published var explorationDistance: Double = 0.0

    /// 生存天数
    @Published var survivalDays: Int = 0

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    private init() {
        // 监听领地上传通知
        NotificationCenter.default.publisher(for: TerritoryManager.territoryUploadedNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshStats()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 公共方法

    /// 刷新所有统计数据
    func refreshStats() async {
        print("📊 StatsManager: 开始刷新统计数据")

        isLoading = true
        errorMessage = nil

        await withTaskGroup(of: Void.self) { group in
            // 并行查询各项数据
            group.addTask { await self.loadTerritoryCount() }
            group.addTask { await self.loadResourcePointCount() }
            group.addTask { await self.loadExplorationDistance() }
            group.addTask { await self.loadSurvivalDays() }
        }

        isLoading = false

        print("📊 StatsManager: 统计数据刷新完成")
        print("   - 领地: \(territoryCount)")
        print("   - 资源点: \(resourcePointCount)")
        print("   - 探索距离: \(String(format: "%.1f", explorationDistance)) km")
        print("   - 生存天数: \(survivalDays)")
    }

    // MARK: - 私有方法

    /// 加载领地数量
    private func loadTerritoryCount() async {
        do {
            // 获取当前用户 ID
            guard let userId = try? await supabase.auth.session.user.id else {
                print("❌ StatsManager: 用户未登录，无法查询领地数量")
                return
            }

            // 查询领地数量
            struct CountResponse: Decodable {
                let count: Int
            }

            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value

            await MainActor.run {
                self.territoryCount = response.count
                print("✅ StatsManager: 领地数量 = \(response.count)")
            }
        } catch {
            print("❌ StatsManager: 查询领地数量失败 - \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "查询领地数量失败"
            }
        }
    }

    /// 加载资源点数量
    private func loadResourcePointCount() async {
        do {
            // 获取当前用户 ID
            guard let userId = try? await supabase.auth.session.user.id else {
                print("❌ StatsManager: 用户未登录，无法查询资源点数量")
                return
            }

            // 查询资源点数量（POIs 表）
            struct POI: Decodable {
                let id: String
            }

            let response: [POI] = try await supabase
                .from("pois")
                .select("id")
                .eq("discovered_by", value: userId.uuidString)
                .execute()
                .value

            await MainActor.run {
                self.resourcePointCount = response.count
                print("✅ StatsManager: 资源点数量 = \(response.count)")
            }
        } catch {
            print("❌ StatsManager: 查询资源点数量失败 - \(error.localizedDescription)")
            // 资源点功能可能还未实现，不设置错误信息
        }
    }

    /// 加载探索距离
    private func loadExplorationDistance() async {
        do {
            // 获取当前用户 ID
            guard let userId = try? await supabase.auth.session.user.id else {
                print("❌ StatsManager: 用户未登录，无法查询探索距离")
                return
            }

            // 查询所有领地，累加路径距离
            let territories: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value

            // 计算总距离
            var totalDistance: Double = 0.0
            for territory in territories {
                let coordinates = territory.toCoordinates()
                guard coordinates.count >= 2 else { continue }

                // 计算这个领地的路径总距离
                for i in 0..<(coordinates.count - 1) {
                    let current = coordinates[i]
                    let next = coordinates[i + 1]

                    // 使用 Haversine 公式计算距离（米）
                    let distance = calculateDistance(
                        lat1: current.latitude,
                        lon1: current.longitude,
                        lat2: next.latitude,
                        lon2: next.longitude
                    )
                    totalDistance += distance
                }
            }

            // 转换为公里
            let distanceKm = totalDistance / 1000.0

            await MainActor.run {
                self.explorationDistance = distanceKm
                print("✅ StatsManager: 探索距离 = \(String(format: "%.1f", distanceKm)) km")
            }
        } catch {
            print("❌ StatsManager: 查询探索距离失败 - \(error.localizedDescription)")
        }
    }

    /// 加载生存天数
    private func loadSurvivalDays() async {
        do {
            // 获取当前用户信息
            let user = try await supabase.auth.session.user

            // 查询用户 profile，获取账户创建时间
            struct Profile: Decodable {
                let createdAt: Date?

                enum CodingKeys: String, CodingKey {
                    case createdAt = "created_at"
                }
            }

            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select("created_at")
                .eq("id", value: user.id.uuidString)
                .execute()
                .value

            let createdAt = profiles.first?.createdAt ?? user.createdAt

            // 计算生存天数
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.day], from: createdAt, to: now)
            let days = max(1, components.day ?? 1)  // 至少1天

            await MainActor.run {
                self.survivalDays = days
                print("✅ StatsManager: 生存天数 = \(days)")
            }
        } catch {
            print("❌ StatsManager: 查询生存天数失败 - \(error.localizedDescription)")
            // 默认设置为 1 天
            await MainActor.run {
                self.survivalDays = 1
            }
        }
    }

    // MARK: - 辅助方法

    /// 使用 Haversine 公式计算两点之间的距离（米）
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius: Double = 6371000  // 地球半径（米）

        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }
}
