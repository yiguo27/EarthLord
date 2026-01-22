//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具 - 实现 WGS-84 到 GCJ-02 的坐标转换
//  用于解决中国地区 GPS 偏移问题，确保轨迹显示在正确位置
//

import Foundation
import CoreLocation

// MARK: - CoordinateConverter

/// 坐标转换器
/// 功能：将 GPS 原始坐标（WGS-84）转换为中国地图使用的坐标（GCJ-02）
/// 原因：中国法规要求地图使用 GCJ-02 加密坐标，如果不转换，轨迹会偏移 100-500 米！
struct CoordinateConverter {

    // MARK: - 常量

    /// 长半轴（地球赤道半径）
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    // MARK: - Public Methods

    /// WGS-84 转 GCJ-02
    /// - Parameter coordinate: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图坐标）
    static func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // 判断是否在中国境内，境外不需要转换
        if isOutOfChina(lat: lat, lon: lon) {
            return coordinate
        }

        // 计算偏移量
        var dLat = transformLat(x: lon - 105.0, y: lat - 35.0)
        var dLon = transformLon(x: lon - 105.0, y: lat - 35.0)

        let radLat = lat / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)

        let gcjLat = lat + dLat
        let gcjLon = lon + dLon

        return CLLocationCoordinate2D(latitude: gcjLat, longitude: gcjLon)
    }

    /// 批量转换坐标数组
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ToGcj02(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - Private Methods

    /// 判断坐标是否在中国境外
    /// - Parameters:
    ///   - lat: 纬度
    ///   - lon: 经度
    /// - Returns: 是否在中国境外
    private static func isOutOfChina(lat: Double, lon: Double) -> Bool {
        // 简单的矩形边界判断（中国大致范围）
        // 纬度：3.86 ~ 53.55
        // 经度：73.66 ~ 135.05
        if lon < 72.004 || lon > 137.8347 {
            return true
        }
        if lat < 0.8293 || lat > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度转换
    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}
