//
//  LocationManager.swift
//  EarthLord
//
//  GPS定位管理器 - 负责请求定位权限、获取用户位置
//

import Foundation
import CoreLocation
import Combine

// MARK: - LocationManager

/// GPS定位管理器
/// 功能：请求定位权限、实时获取用户位置、处理授权状态变化
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置（经纬度坐标）
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - Private Properties

    /// CoreLocation管理器
    private let locationManager = CLLocationManager()

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
