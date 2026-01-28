//
//  LocationCoreManager.swift
//  EarthLord
//
//  优化版：核心位置管理器 - 只包含关键状态
//

import CoreLocation
import Foundation
import Combine

@MainActor
final class LocationCoreManager: NSObject, ObservableObject {
    static let shared = LocationCoreManager()

    // MARK: - Published 属性（仅关键状态）

    /// 用户当前位置
    @Published var userLocation: CLLocationCoordinate2D?

    /// 权限状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 定位错误
    @Published var locationError: String?

    /// 是否正在追踪
    @Published var isTracking: Bool = false

    // MARK: - 私有属性

    private let locationManager = CLLocationManager()
    private var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy

    // MARK: - 计算属性（不触发重渲染）

    /// 是否有精确定位权限
    var hasPreciseLocation: Bool {
        accuracyAuthorization == .fullAccuracy
    }

    /// 是否有定位权限
    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    // MARK: - 初始化

    private override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true

        // 初始化权限状态
        authorizationStatus = locationManager.authorizationStatus
        accuracyAuthorization = locationManager.accuracyAuthorization
    }

    // MARK: - 公共方法

    /// 请求定位权限
    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    /// 请求临时精确定位
    func requestTemporaryFullAccuracy() {
        locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "ClaimTerritory") { error in
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.locationError = "申请精确定位失败: \(error.localizedDescription)"
                }
            }
        }
    }

    /// 开始定位
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    /// 停止定位
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    /// 获取当前位置（一次性）
    func getCurrentLocation() async throws -> CLLocationCoordinate2D {
        if let location = userLocation {
            return location
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false

            let handler: (CLLocationCoordinate2D) -> Void = { location in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: location)
            }

            // 临时订阅位置更新
            let cancellable = $userLocation
                .compactMap { $0 }
                .first()
                .sink { location in
                    handler(location)
                }

            // 开始定位
            startUpdatingLocation()

            // 超时处理
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒
                if !resumed {
                    resumed = true
                    cancellable.cancel()
                    continuation.resume(throwing: NSError(
                        domain: "LocationError",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "获取位置超时"]
                    ))
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationCoreManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // 更新用户位置
        userLocation = location.coordinate

        // 通知其他管理器
        if isTracking {
            PathTrackingManager.shared.handleLocationUpdate(location)
            SpeedMonitor.shared.updateSpeed(from: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "定位失败: \(error.localizedDescription)"
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization

        // 权限变化时清除错误
        locationError = nil
    }
}
