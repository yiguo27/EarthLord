//
//  PlayerLocation.swift
//  EarthLord
//
//  玩家位置数据模型 - 与 player_locations 表对应
//

import Foundation
import CoreLocation

/// 玩家位置数据模型
struct PlayerLocation: Codable {
    let id: String?
    let userId: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let isOnline: Bool
    let lastReportAt: Date
    let deviceId: String?
    let appVersion: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case latitude
        case longitude
        case accuracy
        case isOnline = "is_online"
        case lastReportAt = "last_report_at"
        case deviceId = "device_id"
        case appVersion = "app_version"
        case createdAt = "created_at"
    }

    /// 转换为 CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 用于上传的位置数据（UPSERT）
struct PlayerLocationUpload: Encodable {
    let userId: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let isOnline: Bool
    let lastReportAt: String  // ISO8601 格式
    let deviceId: String?
    let appVersion: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case latitude
        case longitude
        case accuracy
        case isOnline = "is_online"
        case lastReportAt = "last_report_at"
        case deviceId = "device_id"
        case appVersion = "app_version"
    }
}
