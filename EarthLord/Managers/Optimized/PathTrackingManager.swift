//
//  PathTrackingManager.swift
//  EarthLord
//
//  优化版：路径追踪管理器 - 分离高频更新状态
//

import CoreLocation
import Foundation
import Combine

@MainActor
final class PathTrackingManager: ObservableObject {
    static let shared = PathTrackingManager()

    // MARK: - Published 属性

    /// 路径坐标数组
    @Published private(set) var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本（用于触发地图重绘）
    @Published private(set) var pathUpdateVersion: Int = 0

    /// 路径是否闭合
    @Published var isPathClosed: Bool = false

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误
    @Published var territoryValidationError: String?

    /// 计算的面积（平方米）
    @Published private(set) var calculatedArea: Double = 0

    // MARK: - 私有属性

    private var lastLocation: CLLocation?
    private let trackingInterval: TimeInterval = 2.0
    private var lastTrackingTime: Date = .distantPast
    private let minDistanceThreshold: CLLocationDistance = 5.0

    // MARK: - 公共方法

    /// 开始追踪
    func startTracking() {
        pathCoordinates.removeAll()
        pathUpdateVersion = 0
        isPathClosed = false
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        lastLocation = nil
        lastTrackingTime = .distantPast

        print("📍 PathTracking: 开始追踪")
    }

    /// 停止追踪
    func stopTracking() {
        print("📍 PathTracking: 停止追踪，总共 \(pathCoordinates.count) 个点")
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion = 0
        isPathClosed = false
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        lastLocation = nil
        lastTrackingTime = .distantPast

        print("📍 PathTracking: 清除路径")
    }

    /// 处理位置更新（由 LocationCoreManager 调用）
    func handleLocationUpdate(_ location: CLLocation) {
        // 检查时间间隔
        let now = Date()
        guard now.timeIntervalSince(lastTrackingTime) >= trackingInterval else {
            return
        }

        // 检查距离阈值
        if let lastLoc = lastLocation {
            let distance = location.distance(from: lastLoc)
            guard distance >= minDistanceThreshold else {
                return
            }
        }

        // 记录点
        recordPathPoint(location)
        lastLocation = location
        lastTrackingTime = now
    }

    /// 闭合路径
    func closePath() {
        guard pathCoordinates.count >= 3 else {
            territoryValidationError = "至少需要3个点才能闭合路径"
            return
        }

        isPathClosed = true
        pathUpdateVersion += 1

        // 计算面积
        calculatedArea = calculateArea(coordinates: pathCoordinates)

        print("📍 PathTracking: 路径已闭合，面积: \(calculatedArea) m²")
    }

    /// 验证领地
    func validateTerritory() async {
        guard isPathClosed else {
            territoryValidationError = "请先闭合路径"
            return
        }

        print("📍 PathTracking: 开始验证领地...")

        // 1. 检查面积
        if calculatedArea < 100 {
            territoryValidationError = "领地面积过小（最小100m²）"
            territoryValidationPassed = false
            return
        }

        if calculatedArea > 10000000 {
            territoryValidationError = "领地面积过大（最大10km²）"
            territoryValidationPassed = false
            return
        }

        // 2. 检查点数量
        if pathCoordinates.count < 3 {
            territoryValidationError = "路径点数量不足"
            territoryValidationPassed = false
            return
        }

        // 3. 检查自相交（简化版）
        if hasPathSelfIntersection() {
            territoryValidationError = "路径不能自相交"
            territoryValidationPassed = false
            return
        }

        // 验证通过
        territoryValidationPassed = true
        territoryValidationError = nil

        print("✅ PathTracking: 领地验证通过")
    }

    // MARK: - 私有方法

    /// 记录路径点
    private func recordPathPoint(_ location: CLLocation) {
        let coordinate = location.coordinate

        // ✅ 使用 append 而不是创建新数组，减少内存复制
        pathCoordinates.append(coordinate)
        pathUpdateVersion += 1

        print("📍 PathTracking: 记录点 #\(pathCoordinates.count): (\(coordinate.latitude), \(coordinate.longitude))")
    }

    /// 计算多边形面积（使用 Shoelace 公式）
    private func calculateArea(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 3 else { return 0 }

        // 转换为平面坐标（简化，假设小范围）
        let earthRadius: Double = 6371000 // 米

        var area: Double = 0

        for i in 0..<coordinates.count {
            let j = (i + 1) % coordinates.count

            let lat1 = coordinates[i].latitude * .pi / 180
            let lon1 = coordinates[i].longitude * .pi / 180
            let lat2 = coordinates[j].latitude * .pi / 180
            let lon2 = coordinates[j].longitude * .pi / 180

            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2)

        return area
    }

    /// 检查路径自相交（简化版）
    private func hasPathSelfIntersection() -> Bool {
        guard pathCoordinates.count >= 4 else { return false }

        // 检查相邻线段是否相交
        for i in 0..<pathCoordinates.count - 1 {
            let p1 = pathCoordinates[i]
            let p2 = pathCoordinates[i + 1]

            for j in (i + 2)..<pathCoordinates.count - 1 {
                let p3 = pathCoordinates[j]
                let p4 = pathCoordinates[j + 1]

                if lineSegmentsIntersect(p1, p2, p3, p4) {
                    return true
                }
            }
        }

        return false
    }

    /// 判断两条线段是否相交
    private func lineSegmentsIntersect(
        _ p1: CLLocationCoordinate2D,
        _ p2: CLLocationCoordinate2D,
        _ p3: CLLocationCoordinate2D,
        _ p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ c: CLLocationCoordinate2D) -> Bool {
            return (c.latitude - a.latitude) * (b.longitude - a.longitude) >
                   (b.latitude - a.latitude) * (c.longitude - a.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }
}
