//
//  PlayerLocationManager.swift
//  EarthLord
//
//  玩家位置上报管理器
//  职责：管理玩家位置的上报（App启动、定时30秒、移动50米、后台离线标记）
//

import Foundation
import CoreLocation
import Combine
import UIKit
import Supabase

/// 玩家位置上报管理器
@MainActor
final class PlayerLocationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PlayerLocationManager()

    // MARK: - Published Properties

    /// 最后上报的位置
    @Published private(set) var lastReportedLocation: CLLocationCoordinate2D?

    /// 最后上报时间
    @Published private(set) var lastReportTime: Date?

    /// 上报状态
    @Published private(set) var isReporting: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// 定时上报器
    private var reportTimer: Timer?

    /// 上报间隔（秒）
    private let reportInterval: TimeInterval = 30.0

    /// 触发立即上报的移动距离阈值（米）
    private let movementThreshold: CLLocationDistance = 50.0

    /// 设备ID
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    /// App版本
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// 位置监听取消令牌
    private var cancellables = Set<AnyCancellable>()

    /// 是否已启动
    private var isStarted: Bool = false

    /// 弱引用的 LocationManager
    private weak var locationManagerRef: LocationManager?

    // MARK: - Constants

    /// 在线判断阈值（秒）- 5分钟
    static let onlineThreshold: TimeInterval = 5 * 60

    // MARK: - Initialization

    private init() {
        setupAppLifecycleObservers()
    }

    // MARK: - Public Methods

    /// 启动位置上报服务
    /// - Parameter locationManager: 共享的位置管理器
    func start(with locationManager: LocationManager) {
        guard !isStarted else {
            print("⚠️ PlayerLocationManager: 已经启动")
            return
        }

        isStarted = true
        locationManagerRef = locationManager
        print("🚀 PlayerLocationManager: 启动位置上报服务")

        // 1. 立即上报一次（App启动）
        Task {
            await reportLocationOnce(from: locationManager)
        }

        // 2. 启动定时上报（每30秒）
        startReportTimer(locationManager: locationManager)

        // 3. 监听位置变化（移动超过50米立即上报）
        setupLocationObserver(locationManager: locationManager)
    }

    /// 停止位置上报服务
    func stop() {
        guard isStarted else { return }

        isStarted = false
        print("🛑 PlayerLocationManager: 停止位置上报服务")

        // 停止定时器
        reportTimer?.invalidate()
        reportTimer = nil

        // 取消订阅
        cancellables.removeAll()

        // 标记离线
        Task {
            await markOffline()
        }
    }

    /// 手动上报位置（供探索模块调用）
    func reportNow(location: CLLocationCoordinate2D, accuracy: Double? = nil) async {
        await reportLocation(
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: accuracy,
            isOnline: true
        )
    }

    // MARK: - Private Methods

    /// 设置App生命周期观察者
    private func setupAppLifecycleObservers() {
        // 进入后台时标记离线
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("📴 PlayerLocationManager: App进入后台，标记离线")
                await self?.markOffline()
            }
        }

        // 回到前台时标记在线并上报
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isStarted, let locationManager = self.locationManagerRef else { return }
                print("📱 PlayerLocationManager: App回到前台，重新上报")
                await self.reportLocationOnce(from: locationManager)
            }
        }
    }

    /// 启动定时上报
    private func startReportTimer(locationManager: LocationManager) {
        reportTimer?.invalidate()

        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let locationManager = self.locationManagerRef else { return }
                await self.reportLocationOnce(from: locationManager)
            }
        }

        print("⏱️ PlayerLocationManager: 定时上报已启动（间隔\(Int(reportInterval))秒）")
    }

    /// 监听位置变化
    private func setupLocationObserver(locationManager: LocationManager) {
        locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] newLocation in
                guard let self = self else { return }

                // 检查是否移动超过50米
                if let lastLocation = self.lastReportedLocation {
                    let lastLoc = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
                    let newLoc = CLLocation(latitude: newLocation.latitude, longitude: newLocation.longitude)
                    let distance = lastLoc.distance(from: newLoc)

                    if distance >= self.movementThreshold {
                        print("📍 PlayerLocationManager: 移动超过\(Int(self.movementThreshold))米，立即上报")
                        Task {
                            await self.reportNow(location: newLocation)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// 从LocationManager获取位置并上报
    private func reportLocationOnce(from locationManager: LocationManager) async {
        guard let location = locationManager.userLocation else {
            print("⚠️ PlayerLocationManager: 无法获取当前位置")
            return
        }

        await reportLocation(
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: nil,
            isOnline: true
        )
    }

    /// 上报位置到数据库
    private func reportLocation(
        latitude: Double,
        longitude: Double,
        accuracy: Double?,
        isOnline: Bool
    ) async {
        guard !isReporting else {
            print("⚠️ PlayerLocationManager: 上报进行中，跳过")
            return
        }

        isReporting = true
        defer { isReporting = false }

        do {
            // 获取当前用户ID
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString

            // 构造上传数据
            let uploadData = PlayerLocationUpload(
                userId: userId,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                isOnline: isOnline,
                lastReportAt: ISO8601DateFormatter().string(from: Date()),
                deviceId: deviceId,
                appVersion: appVersion
            )

            // UPSERT（有则更新，无则插入）
            try await supabase
                .from("player_locations")
                .upsert(uploadData, onConflict: "user_id")
                .execute()

            // 更新状态
            lastReportedLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            lastReportTime = Date()
            errorMessage = nil

            print("✅ PlayerLocationManager: 位置上报成功 (\(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude)))")

        } catch {
            print("❌ PlayerLocationManager: 位置上报失败 - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// 标记离线
    private func markOffline() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString

            struct OfflineUpdate: Encodable {
                let is_online: Bool
            }

            try await supabase
                .from("player_locations")
                .update(OfflineUpdate(is_online: false))
                .eq("user_id", value: userId)
                .execute()

            print("📴 PlayerLocationManager: 已标记离线")

        } catch {
            print("❌ PlayerLocationManager: 标记离线失败 - \(error.localizedDescription)")
        }
    }
}
