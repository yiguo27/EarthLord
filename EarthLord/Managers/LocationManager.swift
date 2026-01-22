//
//  LocationManager.swift
//  EarthLord
//
//  GPS定位管理器 - 负责请求定位权限、获取用户位置、路径追踪
//

import Foundation
import CoreLocation
import Combine

// MARK: - LocationManager

/// GPS定位管理器
/// 功能：请求定位权限、实时获取用户位置、处理授权状态变化、路径追踪
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置（经纬度坐标）
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - 路径追踪相关属性

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（Day16 会用到）
    @Published var isPathClosed: Bool = false

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
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新位置

        // 获取当前授权状态
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public Methods

    /// 请求定位权限（使用App期间）
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
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

        // 清除之前的路径
        clearPath()

        // 设置追踪状态
        isTracking = true

        // 记录起始点（如果有当前位置）
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
        }

        // 启动定时器，每 2 秒检查一次是否需要记录新点
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("📍 开始圈地追踪")
    }

    /// 停止路径追踪
    func stopPathTracking() {
        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 更新状态
        isTracking = false

        print("🛑 停止圈地追踪，共记录 \(pathCoordinates.count) 个点")
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 确保有当前位置
        guard let location = currentLocation else {
            print("⚠️ 无法获取当前位置")
            return
        }

        // 如果路径为空，直接添加第一个点
        guard let lastCoordinate = pathCoordinates.last else {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            print("📍 记录起始点: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            return
        }

        // 计算与上一个点的距离
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = location.distance(from: lastLocation)

        // 只有移动超过 minimumDistance 才记录新点
        if distance >= minimumDistance {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            print("📍 记录新点: \(location.coordinate.latitude), \(location.coordinate.longitude)，距离上点 \(String(format: "%.1f", distance)) 米")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态改变时调用
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 更新授权状态
        authorizationStatus = manager.authorizationStatus

        // 如果已授权，自动开始定位
        if isAuthorized {
            locationError = nil
            startUpdatingLocation()
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
