//
//  LocationManager.swift
//  EarthLord
//
//  GPS定位管理器 - 负责请求定位权限、获取用户位置、路径追踪、闭环检测、速度检测、领地验证
//

import Foundation
import CoreLocation
import Combine

// MARK: - LocationManager

/// GPS定位管理器
/// 功能：请求定位权限、实时获取用户位置、处理授权状态变化、路径追踪、闭环检测、速度检测、领地验证
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置（经纬度坐标）
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 精确位置授权状态（iOS 14+）
    @Published var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy

    /// 是否拥有精确位置权限
    @Published var hasPreciseLocation: Bool = true

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - 路径追踪相关属性

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合
    @Published var isPathClosed: Bool = false

    // MARK: - 速度检测相关属性

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速（用于 UI 显示）
    @Published var isOverSpeed: Bool = false

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证失败原因
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - 验证常量

    /// 最少路径点数 - 至少需要这么多点才能判断闭环
    private let minimumPathPoints: Int = 10

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    /// 闭环距离阈值（米）- 距离起点小于此值视为闭环
    private let closureDistanceThreshold: Double = 30.0

    // MARK: - Private Properties

    /// CoreLocation管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（供 Timer 采点使用）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 采点间隔（秒）
    private let trackingInterval: TimeInterval = 2.0

    /// 最小移动距离（米），超过此距离才记录新点
    private let minimumDistance: CLLocationDistance = 10.0

    /// 上次记录位置的时间戳（用于速度检测）
    private var lastRecordedTimestamp: Date?

    /// 上次记录的位置（用于速度检测）
    private var lastRecordedLocation: CLLocation?

    // MARK: - Computed Properties

    /// 是否已授权（允许使用定位）
    var isAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse ||
               authorizationStatus == .authorizedAlways
    }

    /// 是否被拒绝（用户拒绝定位权限）
    var isDenied: Bool {
        return authorizationStatus == .denied ||
               authorizationStatus == .restricted
    }

    // MARK: - Initialization

    override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation  // 导航级最高精度
        locationManager.distanceFilter = 5  // 移动5米就更新位置（更精确）
        locationManager.activityType = .fitness  // 健身活动类型，适合步行追踪
        locationManager.pausesLocationUpdatesAutomatically = false  // 不自动暂停

        // 获取当前授权状态
        authorizationStatus = locationManager.authorizationStatus

        // 获取精确位置授权状态（iOS 14+）
        accuracyAuthorization = locationManager.accuracyAuthorization
        hasPreciseLocation = (accuracyAuthorization == .fullAccuracy)
    }

    // MARK: - Public Methods

    /// 请求定位权限（使用App期间）
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 检查并提示精确位置权限（iOS 14+）
    /// 当用户选择了"模糊位置"时，提示用户去设置中开启
    func requestPreciseLocation() {
        // 检查当前是否已经有精确位置权限
        guard accuracyAuthorization == .reducedAccuracy else {
            TerritoryLogger.shared.info("已拥有精确位置权限")
            return
        }

        // 提示用户去设置中开启精确位置
        TerritoryLogger.shared.warning("当前为模糊定位，建议在设置中开启精确位置")
        locationError = "请在设置中开启精确位置以获得更好的圈地体验"
    }

    /// 开始获取位置
    func startUpdatingLocation() {
        // 先检查是否已授权
        guard isAuthorized else {
            locationError = "未获得定位权限"
            return
        }

        locationManager.startUpdatingLocation()
    }

    /// 停止获取位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪
    func startPathTracking() {
        // 确保已授权
        guard isAuthorized else {
            locationError = "未获得定位权限，无法开始圈地"
            return
        }

        // ⭐ iOS 14+ 检查精确位置权限
        if accuracyAuthorization == .reducedAccuracy {
            TerritoryLogger.shared.warning("当前为模糊定位，正在请求精确位置...")
            requestPreciseLocation()
            // 即使没有精确位置也允许开始，但会提示用户
            locationError = "建议开启精确位置以获得更好的圈地体验"
        }

        // 清除之前的路径
        clearPath()

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastRecordedTimestamp = nil
        lastRecordedLocation = nil

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 设置追踪状态
        isTracking = true

        // 记录起始点（如果有当前位置）
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            // 记录起始时间戳和位置（用于速度检测）
            lastRecordedTimestamp = Date()
            lastRecordedLocation = location
        }

        // 启动定时器，每 2 秒检查一次是否需要记录新点
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        // 📋 记录日志：开始圈地
        TerritoryLogger.shared.info("开始圈地追踪")
    }

    /// 停止路径追踪
    func stopPathTracking() {
        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 更新状态
        isTracking = false

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastRecordedTimestamp = nil
        lastRecordedLocation = nil

        // 📋 记录日志：停止圈地
        TerritoryLogger.shared.info("停止圈地追踪")
    }

    /// 完全重置所有圈地状态（上传成功后调用）
    func resetPathState() {
        isPathClosed = false
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        pathCoordinates.removeAll()
        pathUpdateVersion += 1

        // 📋 记录日志：重置状态
        TerritoryLogger.shared.info("圈地状态已完全重置")
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastRecordedTimestamp = nil
        lastRecordedLocation = nil
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离（米）
    /// 遍历相邻点，使用 CLLocation 的 distance(from:) 累加
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let currentCoord = pathCoordinates[i]
            let nextCoord = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
            let nextLocation = CLLocation(latitude: nextCoord.latitude, longitude: nextCoord.longitude)

            totalDistance += currentLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    /// 使用鞋带公式计算多边形面积（平方米）
    /// 采用球面修正公式，考虑地球曲率
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        // 地球半径（米）
        let earthRadius: Double = 6371000

        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)

        return area
    }

    // MARK: - 自相交检测（CCW 算法）

    /// 判断三个点是否为逆时针方向（CCW 算法核心）
    /// - Parameters:
    ///   - A: 第一个点
    ///   - B: 第二个点
    ///   - C: 第三个点
    /// - Returns: true 表示逆时针，false 表示顺时针或共线
    /// - Note: longitude = X轴，latitude = Y轴
    private func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
        // 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
        let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                           (B.latitude - A.latitude) * (C.longitude - A.longitude)
        return crossProduct > 0
    }

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        // 判断逻辑：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且
        // ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) &&
               ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测整条路径是否存在自相交
    /// - Returns: true 表示有自交，false 表示无自交
    /// - Note: 包含多重防御性措施防止闪退和误判
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（防止正常圈地被误判为自交）
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            // ✅ 循环内索引检查
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                // ✅ 循环内索引检查
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较（防止正常闭环被误判）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    // 📋 记录日志：发现自交
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        // 📋 记录日志：检测通过（不在这里打印，由 validateTerritory 统一打印）
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (isValid: 是否有效, errorMessage: 错误信息)
    /// 验证顺序：点数 → 距离 → 自交 → 面积
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.info("开始领地验证")

        // ========== 验证1：点数检查 ==========
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let errorMsg = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(pointCount)个 ✗", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.info("点数检查: \(pointCount)个点 ✓")

        // ========== 验证2：距离检查 ==========
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let errorMsg = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✗", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.info("距离检查: \(String(format: "%.0f", totalDistance))m ✓")

        // ========== 验证3：自交检测 ==========
        if hasPathSelfIntersection() {
            let errorMsg = "轨迹自相交，请勿画8字形"
            // 日志已在 hasPathSelfIntersection 中打印
            return (false, errorMsg)
        }
        TerritoryLogger.shared.info("自交检测: 无交叉 ✓")

        // ========== 验证4：面积检查 ==========
        let area = calculatePolygonArea()
        calculatedArea = area  // 保存面积供 UI 显示

        if area < minimumEnclosedArea {
            let errorMsg = "面积不足: \(String(format: "%.0f", area))m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✗", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.info("面积检查: \(String(format: "%.0f", area))m² ✓")

        // ========== 所有验证通过 ==========
        TerritoryLogger.shared.success("领地验证通过！面积: \(String(format: "%.0f", area))m²")

        return (true, nil)
    }

    // MARK: - 闭环检测方法

    /// 检测路径是否闭合
    /// 条件：路径点数 >= 10 且当前位置距起点 <= 30米
    /// ⚠️ 已闭环则不再重复检测，避免日志刷屏
    private func checkPathClosure() {
        // ⚠️ 关键：已闭环则不再检测
        guard !isPathClosed else { return }

        // 检查点数是否足够
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            // 点数不足时不打印日志（避免刷屏）
            return
        }

        // 获取起点坐标
        guard let startCoordinate = pathCoordinates.first else {
            return
        }

        // 获取当前位置
        guard let currentLoc = currentLocation else {
            return
        }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
        let distanceToStart = currentLoc.distance(from: startLocation)

        // 检查是否满足闭环距离条件
        if distanceToStart > closureDistanceThreshold {
            // 📋 记录日志：距离信息（点数 ≥10 时才显示）
            TerritoryLogger.shared.info("距起点 \(String(format: "%.0f", distanceToStart))m (需≤\(Int(closureDistanceThreshold))m)")
            return
        }

        // ========== 闭环距离满足，设置闭环状态 ==========
        TerritoryLogger.shared.info("--- 闭环成功，开始领地验证 ---")

        // 设置闭环状态
        isPathClosed = true
        pathUpdateVersion += 1  // 触发 UI 更新

        // ========== 执行领地验证 ==========
        let (isValid, errorMessage) = validateTerritory()

        // 更新验证状态
        territoryValidationPassed = isValid
        territoryValidationError = errorMessage
    }

    // MARK: - 速度检测方法

    /// 验证移动速度是否合法
    /// - Parameter newLocation: 新的位置
    /// - Returns: true 表示可以记录该点，false 表示不记录（严重超速）
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 如果是第一个点，没有上次位置，直接通过
        guard let lastLocation = lastRecordedLocation,
              let lastTimestamp = lastRecordedTimestamp else {
            // 更新记录
            lastRecordedLocation = newLocation
            lastRecordedTimestamp = Date()
            return true
        }

        // 计算与上一个记录点的距离（米）
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTimestamp)

        // 防止除以零
        guard timeInterval > 0 else {
            return true
        }

        // 计算速度（km/h）
        // 速度 = 距离(米) / 时间(秒) * 3.6 = km/h
        let speedKmh = (distance / timeInterval) * 3.6

        // 严重超速（>30 km/h）：停止追踪
        if speedKmh > 30 {
            DispatchQueue.main.async {
                self.speedWarning = "速度过快（\(String(format: "%.0f", speedKmh)) km/h），追踪已暂停"
                self.isOverSpeed = true
            }
            // 📋 记录日志：严重超速
            TerritoryLogger.shared.log("超速 \(String(format: "%.0f", speedKmh)) km/h，已停止追踪", type: .error)
            stopPathTracking()
            return false
        }

        // 轻度超速（>15 km/h）：警告但继续记录
        if speedKmh > 15 {
            DispatchQueue.main.async {
                self.speedWarning = "移动速度较快（\(String(format: "%.0f", speedKmh)) km/h），请步行圈地"
                self.isOverSpeed = true

                // 3秒后自动清除警告
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.speedWarning?.contains("\(String(format: "%.0f", speedKmh))") == true {
                        self.speedWarning = nil
                        self.isOverSpeed = false
                    }
                }
            }
            // 📋 记录日志：轻度超速警告
            TerritoryLogger.shared.warning("速度较快 \(String(format: "%.0f", speedKmh)) km/h，继续记录")
        } else {
            // 速度正常，清除警告
            DispatchQueue.main.async {
                if self.isOverSpeed && self.isTracking {
                    self.speedWarning = nil
                    self.isOverSpeed = false
                }
            }
        }

        // 更新记录的位置和时间戳
        lastRecordedLocation = newLocation
        lastRecordedTimestamp = Date()

        return true
    }

    /// 定时器回调 - 记录路径点
    /// ⚠️ 关键：先检查距离，再检查速度！顺序不能反！
    private func recordPathPoint() {
        // 确保正在追踪且有当前位置
        guard isTracking, let location = currentLocation else {
            return
        }

        // 如果已经闭环，不再记录新点
        if isPathClosed {
            return
        }

        // 步骤1：先检查距离（过滤 GPS 漂移，距离不够就直接返回）
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            guard distance > minimumDistance else {
                // 距离不够，不进行速度检测，直接返回
                return
            }
        }

        // 步骤2：再检查速度（只对真实移动进行检测）
        guard validateMovementSpeed(newLocation: location) else {
            // 严重超速，不记录
            return
        }

        // 步骤3：记录新点
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1

        // 计算与上一点的距离（用于日志显示）
        var distanceInfo = ""
        if pathCoordinates.count > 1 {
            let prevCoord = pathCoordinates[pathCoordinates.count - 2]
            let prevLoc = CLLocation(latitude: prevCoord.latitude, longitude: prevCoord.longitude)
            let dist = location.distance(from: prevLoc)
            distanceInfo = "，距上点 \(String(format: "%.0f", dist))m"
        }

        // 📋 记录日志：新点
        TerritoryLogger.shared.info("记录第 \(pathCoordinates.count) 个点\(distanceInfo)")

        // 步骤4：检测闭环
        checkPathClosure()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态改变时调用（包括精确位置权限变化）
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 更新授权状态
        authorizationStatus = manager.authorizationStatus

        // ⭐ iOS 14+ 更新精确位置授权状态
        accuracyAuthorization = manager.accuracyAuthorization
        hasPreciseLocation = (accuracyAuthorization == .fullAccuracy)

        // 记录精确位置状态
        if hasPreciseLocation {
            TerritoryLogger.shared.info("定位精度: 精确位置 ✓")
        } else {
            TerritoryLogger.shared.warning("定位精度: 模糊位置（建议开启精确位置）")
        }

        // 如果已授权，自动开始定位
        if isAuthorized {
            startUpdatingLocation()

            // 如果是模糊定位，给出提示
            if !hasPreciseLocation {
                locationError = "当前为模糊定位，建议在「设置 > 隐私 > 定位服务 > EarthLord」中开启精确位置"
            } else {
                locationError = nil
            }
        } else if isDenied {
            locationError = "定位权限被拒绝，请前往设置开启"
        }
    }

    /// 成功获取位置时调用
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 获取最新的位置
        guard let location = locations.last else { return }

        // ⭐ 关键：更新 currentLocation，供 Timer 采点使用
        self.currentLocation = location

        // 更新用户位置
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.locationError = nil
        }
    }

    /// 定位失败时调用
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "定位失败: \(error.localizedDescription)"
        }
    }
}
