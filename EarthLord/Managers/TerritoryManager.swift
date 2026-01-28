//
//  TerritoryManager.swift
//  EarthLord
//
//  Created by Claude on 2026-01-28.
//

import Foundation
import CoreLocation
import Supabase
import Combine

@MainActor
final class TerritoryManager: ObservableObject {
    static let shared = TerritoryManager()

    @Published var territories: [Territory] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // 通知名称
    static let territoryUploadedNotification = Notification.Name("TerritoryUploaded")

    private init() {}

    // MARK: - 上传数据结构

    /// 用于上传的领地数据结构
    private struct TerritoryUploadData: Encodable {
        let userId: String
        let path: [[String: Double]]
        let polygon: String
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt = "started_at"
            case isActive = "is_active"
        }
    }

    // MARK: - 坐标转换方法

    /// 将坐标数组转为 path JSON 格式：[{"lat": x, "lon": y}, ...]
    /// ⚠️ 不包含 index、timestamp 等额外字段
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coordinate in
            [
                "lat": coordinate.latitude,
                "lon": coordinate.longitude
            ]
        }
    }

    /// 将坐标数组转为 WKT 格式
    /// ⚠️ WKT 是「经度在前，纬度在后」！
    /// ⚠️ 多边形必须闭合（首尾相同）！
    /// 示例：SRID=4326;POLYGON((121.4 31.2, 121.5 31.2, 121.5 31.3, 121.4 31.2))
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        // 确保多边形闭合
        var coords = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            // 如果首尾不同，添加首点到末尾
            if first.latitude != last.latitude || first.longitude != last.longitude {
                coords.append(first)
            }
        }

        // 将坐标转为 WKT 格式字符串（经度在前，纬度在后）
        let pointsString = coords.map { coordinate in
            "\(coordinate.longitude) \(coordinate.latitude)"
        }.joined(separator: ", ")

        return "SRID=4326;POLYGON((\(pointsString)))"
    }

    /// 计算边界框：(minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

        return (
            minLat: latitudes.min() ?? 0,
            maxLat: latitudes.max() ?? 0,
            minLon: longitudes.min() ?? 0,
            maxLon: longitudes.max() ?? 0
        )
    }

    // MARK: - 上传领地

    /// 上传领地到数据库
    /// - Parameters:
    ///   - coordinates: 路径坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地的时间
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        guard !coordinates.isEmpty else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "坐标数组不能为空"])
        }

        // 获取当前用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "TerritoryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }

        // 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox = calculateBoundingBox(coordinates)

        // 准备上传数据
        let territoryData = TerritoryUploadData(
            userId: userId.uuidString,
            path: pathJSON,
            polygon: wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: coordinates.count,
            startedAt: startTime.ISO8601Format(),
            isActive: true
        )

        print("📤 TerritoryManager: 准备上传领地数据")
        print("   - 用户ID: \(userId.uuidString)")
        print("   - 坐标数量: \(coordinates.count)")
        print("   - 面积: \(String(format: "%.2f", area)) m²")
        print("   - 边界框: lat[\(bbox.minLat), \(bbox.maxLat)], lon[\(bbox.minLon), \(bbox.maxLon)]")

        // 上传到数据库
        do {
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("✅ TerritoryManager: 领地上传成功")

            // 📋 记录日志：上传成功
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)

            // 发送通知，通知其他视图刷新
            NotificationCenter.default.post(name: TerritoryManager.territoryUploadedNotification, object: nil)
        } catch {
            print("❌ TerritoryManager: 领地上传失败 - \(error.localizedDescription)")

            // 📋 记录日志：上传失败
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)

            throw error
        }
    }

    // MARK: - 加载领地

    /// 加载所有活跃的领地
    func loadAllTerritories() async throws -> [Territory] {
        print("📥 TerritoryManager: 开始加载领地数据")

        isLoading = true
        errorMessage = nil

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            territories = response
            print("✅ TerritoryManager: 加载了 \(response.count) 个领地")

            isLoading = false
            return response
        } catch {
            let errorMsg = "加载领地失败: \(error.localizedDescription)"
            print("❌ TerritoryManager: \(errorMsg)")
            errorMessage = errorMsg
            isLoading = false
            throw error
        }
    }

    /// 加载当前用户的领地
    func loadMyTerritories() async throws -> [Territory] {
        print("📥 TerritoryManager: 开始加载当前用户的领地数据")

        // 获取当前用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "TerritoryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value

            print("✅ TerritoryManager: 加载了 \(response.count) 个个人领地")

            isLoading = false
            return response
        } catch {
            let errorMsg = "加载个人领地失败: \(error.localizedDescription)"
            print("❌ TerritoryManager: \(errorMsg)")
            errorMessage = errorMsg
            isLoading = false
            throw error
        }
    }

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in otherTerritories {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！",
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: "轨迹不能进入他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越他人领地
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = "注意：距离他人领地 \(Int(minDistance))m"
        } else if minDistance > 25 {
            warningLevel = .warning
            message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
        } else {
            warningLevel = .danger
            message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }
}
