//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器 - 负责GPS追踪、距离计算、时长计时
//

import Foundation
import CoreLocation
import Combine

/// 探索管理器
/// 功能：管理探索状态、GPS轨迹追踪、距离累加、时长计时、过滤无效位置
class ExplorationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前累计距离（米）
    @Published var currentDistance: Double = 0

    /// 当前探索时长（秒）
    @Published var currentDuration: Int = 0

    /// 探索开始时间
    @Published var startTime: Date?

    /// 探索开始位置
    @Published var startLocation: CLLocationCoordinate2D?

    /// 探索结束位置
    @Published var endLocation: CLLocationCoordinate2D?

    // MARK: - Private Properties

    /// 位置管理器
    private let locationManager = CLLocationManager()

    /// 上一个有效位置
    private var lastValidLocation: CLLocation?

    /// 上一个位置的时间戳
    private var lastLocationTimestamp: Date?

    /// 计时器
    private var timer: Timer?

    /// 位置历史（用于调试）
    private var locationHistory: [CLLocation] = []

    // MARK: - Constants

    /// GPS精度阈值（米）- 超过此精度的位置点将被忽略
    private let accuracyThreshold: CLLocationAccuracy = 50.0

    /// 距离跳变阈值（米）- 与上一点距离超过此值的位置点将被忽略
    private let distanceJumpThreshold: CLLocationDistance = 100.0

    /// 最小时间间隔（秒）- 两个位置点之间的最小时间间隔
    private let minimumTimeInterval: TimeInterval = 1.0

    // MARK: - Initialization

    override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Setup

    /// 配置位置管理器
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // 移动5米触发一次更新
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Public Methods

    /// 开始探索
    func startExploration() {
        guard !isExploring else {
            print("⚠️ 探索已经在进行中")
            return
        }

        print("🔍 开始探索")

        // 重置状态
        currentDistance = 0
        currentDuration = 0
        startTime = Date()
        lastValidLocation = nil
        lastLocationTimestamp = nil
        locationHistory.removeAll()
        startLocation = nil
        endLocation = nil

        // 开始GPS追踪
        locationManager.startUpdatingLocation()

        // 开始计时器（每秒更新一次）
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentDuration += 1
            print("⏱️ 探索时长: \(self.currentDuration)秒, 距离: \(Int(self.currentDistance))米")
        }

        isExploring = true
    }

    /// 结束探索
    /// - Returns: 返回探索会话数据，如果距离太短则返回nil
    func stopExploration() -> ExplorationSessionData? {
        guard isExploring else {
            print("⚠️ 当前没有进行中的探索")
            return nil
        }

        print("🛑 结束探索")

        // 停止GPS追踪
        locationManager.stopUpdatingLocation()

        // 停止计时器
        timer?.invalidate()
        timer = nil

        isExploring = false

        // 记录结束位置
        if let lastLocation = lastValidLocation {
            endLocation = lastLocation.coordinate
        }

        // 创建探索会话数据
        guard let start = startTime else {
            print("❌ 探索数据不完整：缺少开始时间")
            return nil
        }

        let sessionData = ExplorationSessionData(
            startTime: start,
            endTime: Date(),
            duration: currentDuration,
            distance: currentDistance,
            startLocation: startLocation,
            endLocation: endLocation,
            locationHistory: locationHistory
        )

        print("✅ 探索完成 - 距离: \(Int(currentDistance))米, 时长: \(currentDuration)秒")

        return sessionData
    }

    /// 取消探索（不保存数据）
    func cancelExploration() {
        guard isExploring else { return }

        print("❌ 取消探索")

        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil

        isExploring = false
        currentDistance = 0
        currentDuration = 0
        startTime = nil
        lastValidLocation = nil
        locationHistory.removeAll()
    }

    // MARK: - Private Methods

    /// 处理新的位置更新
    private func processLocationUpdate(_ location: CLLocation) {
        // 1. 检查GPS精度
        guard location.horizontalAccuracy <= accuracyThreshold else {
            print("⚠️ GPS精度不足: \(location.horizontalAccuracy)米 (阈值: \(accuracyThreshold)米)")
            return
        }

        // 2. 检查时间间隔
        if let lastTimestamp = lastLocationTimestamp {
            let timeInterval = location.timestamp.timeIntervalSince(lastTimestamp)
            guard timeInterval >= minimumTimeInterval else {
                print("⚠️ 时间间隔太短: \(timeInterval)秒 (阈值: \(minimumTimeInterval)秒)")
                return
            }
        }

        // 3. 检查距离跳变
        if let lastLocation = lastValidLocation {
            let distance = location.distance(from: lastLocation)

            guard distance <= distanceJumpThreshold else {
                print("⚠️ 距离跳变异常: \(Int(distance))米 (阈值: \(Int(distanceJumpThreshold))米)")
                return
            }

            // 累加距离
            currentDistance += distance
            print("📍 新位置点 - 增加距离: \(Int(distance))米, 总距离: \(Int(currentDistance))米")
        } else {
            // 第一个有效位置点
            startLocation = location.coordinate
            print("📍 记录起始位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }

        // 4. 更新状态
        lastValidLocation = location
        lastLocationTimestamp = location.timestamp
        locationHistory.append(location)
    }
}

// MARK: - CLLocationManagerDelegate

extension ExplorationManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isExploring else { return }

        // 处理所有新位置
        for location in locations {
            processLocationUpdate(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 位置更新失败: \(error.localizedDescription)")
    }
}

// MARK: - ExplorationSessionData

/// 探索会话数据
struct ExplorationSessionData {
    let startTime: Date
    let endTime: Date
    let duration: Int // 秒
    let distance: Double // 米
    let startLocation: CLLocationCoordinate2D?
    let endLocation: CLLocationCoordinate2D?
    let locationHistory: [CLLocation]

    /// 获取格式化的时长字符串
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d分%d秒", minutes, seconds)
    }

    /// 获取格式化的距离字符串
    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.2f公里", distance / 1000)
        } else {
            return String(format: "%d米", Int(distance))
        }
    }
}
