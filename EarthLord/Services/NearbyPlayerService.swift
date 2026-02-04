//
//  NearbyPlayerService.swift
//  EarthLord
//
//  附近玩家查询服务
//  职责：查询指定位置附近的在线玩家数量，计算密度等级
//

import Foundation
import CoreLocation
import Supabase

/// 附近玩家查询服务
final class NearbyPlayerService {

    // MARK: - Singleton

    static let shared = NearbyPlayerService()

    private init() {}

    // MARK: - Public Methods

    /// 查询附近玩家数量
    /// - Parameters:
    ///   - location: 查询中心点
    ///   - radius: 查询半径（米），默认1000米
    /// - Returns: 附近在线玩家数量（不含自己）
    func getNearbyPlayerCount(
        at location: CLLocationCoordinate2D,
        radius: Int = 1000
    ) async throws -> Int {

        // 获取当前用户ID
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        // 使用 SQL 直接查询（避免 RPC 参数类型问题）
        // 查询 5 分钟内活跃且在 radius 米范围内的玩家
        let fiveMinutesAgo = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-5 * 60))

        // 使用 Haversine 公式计算距离（简化版，对于1km范围足够精确）
        // 1度纬度 ≈ 111km, 1度经度 ≈ 111km * cos(lat)
        let latDelta = Double(radius) / 111000.0
        let lonDelta = Double(radius) / (111000.0 * cos(location.latitude * .pi / 180))

        let response: [PlayerLocation] = try await supabase
            .from("player_locations")
            .select()
            .eq("is_online", value: true)
            .gt("last_report_at", value: fiveMinutesAgo)
            .neq("user_id", value: userId)
            .gte("latitude", value: location.latitude - latDelta)
            .lte("latitude", value: location.latitude + latDelta)
            .gte("longitude", value: location.longitude - lonDelta)
            .lte("longitude", value: location.longitude + lonDelta)
            .execute()
            .value

        // 进一步过滤：精确计算距离
        let playerLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let nearbyCount = response.filter { player in
            let otherLocation = CLLocation(latitude: player.latitude, longitude: player.longitude)
            return playerLocation.distance(from: otherLocation) <= Double(radius)
        }.count

        print("🔍 NearbyPlayerService: 附近 \(radius)m 内有 \(nearbyCount) 名玩家")

        return nearbyCount
    }

    /// 获取玩家密度等级
    /// - Parameter location: 查询位置
    /// - Returns: 密度等级
    func getDensityLevel(at location: CLLocationCoordinate2D) async throws -> PlayerDensityLevel {
        let count = try await getNearbyPlayerCount(at: location)
        let level = PlayerDensityLevel.from(count: count)
        print("📊 NearbyPlayerService: 密度等级 = \(level.displayName)（\(count)人）")
        return level
    }

    /// 根据密度等级计算应该显示的POI数量
    /// - Parameter density: 密度等级
    /// - Returns: POI数量
    func calculatePOICount(for density: PlayerDensityLevel) -> Int {
        let range = density.poiCountRange
        let count = Int.random(in: range)
        print("📍 NearbyPlayerService: 密度 \(density.displayName) → 显示 \(count) 个POI")
        return count
    }

    /// 完整的探索初始化流程
    /// - Parameters:
    ///   - location: 玩家当前位置
    ///   - allPOIs: 所有可用的POI列表
    /// - Returns: (密度等级, 筛选后的POI列表)
    func initializeExploration(
        at location: CLLocationCoordinate2D,
        allPOIs: [POI]
    ) async throws -> (density: PlayerDensityLevel, pois: [POI]) {

        // 1. 查询密度
        let density = try await getDensityLevel(at: location)

        // 2. 计算POI数量
        let poiCount = calculatePOICount(for: density)

        // 3. 计算每个POI到玩家的距离
        let playerLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        var poisWithDistance = allPOIs.map { poi -> (poi: POI, distance: Double) in
            let poiLocation = CLLocation(
                latitude: poi.coordinate.latitude,
                longitude: poi.coordinate.longitude
            )
            let distance = playerLocation.distance(from: poiLocation)
            return (poi, distance)
        }

        // 4. 过滤已搜空的POI
        poisWithDistance = poisWithDistance.filter { $0.poi.status != .looted }

        // 5. 按距离排序
        poisWithDistance.sort { $0.distance < $1.distance }

        // 6. 取前N个
        let selectedPOIs = poisWithDistance.prefix(poiCount).map { $0.poi }

        print("🎯 NearbyPlayerService: 探索初始化完成 - 密度: \(density.displayName), POI数量: \(selectedPOIs.count)")

        return (density, Array(selectedPOIs))
    }
}
