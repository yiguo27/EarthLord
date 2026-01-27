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
}
