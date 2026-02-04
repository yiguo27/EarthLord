//
//  PlayerDensity.swift
//  EarthLord
//
//  玩家密度等级 - 根据附近玩家数量决定POI显示数量
//

import Foundation

/// 玩家密度等级
enum PlayerDensityLevel: String, Codable {
    case solitary = "solitary"    // 独行者：0人
    case low = "low"              // 低密度：1-5人
    case medium = "medium"        // 中密度：6-20人
    case high = "high"            // 高密度：20+人

    /// 根据玩家数量计算密度等级
    static func from(count: Int) -> PlayerDensityLevel {
        switch count {
        case 0:
            return .solitary
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }

    /// 对应的POI数量范围
    var poiCountRange: ClosedRange<Int> {
        switch self {
        case .solitary:
            return 1...1      // 保底1个
        case .low:
            return 2...3
        case .medium:
            return 4...6
        case .high:
            return 7...10     // "所有POI"上限10个
        }
    }

    /// 推荐的POI数量（取范围中间值）
    var recommendedPOICount: Int {
        let range = poiCountRange
        return (range.lowerBound + range.upperBound) / 2
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .solitary:
            return "独行者"
        case .low:
            return "低密度"
        case .medium:
            return "中密度"
        case .high:
            return "高密度"
        }
    }

    /// 显示名称（带图标）
    var displayNameWithIcon: String {
        switch self {
        case .solitary:
            return "独行者"
        case .low:
            return "低密度"
        case .medium:
            return "中密度"
        case .high:
            return "高密度"
        }
    }

    /// 密度描述
    var description: String {
        switch self {
        case .solitary:
            return "附近没有其他探索者"
        case .low:
            return "附近有少量探索者"
        case .medium:
            return "附近探索者较多"
        case .high:
            return "这是一个热门探索区域"
        }
    }

    /// SF Symbol 图标名
    var iconName: String {
        switch self {
        case .solitary:
            return "figure.walk"
        case .low:
            return "person.2"
        case .medium:
            return "person.3"
        case .high:
            return "person.3.fill"
        }
    }
}
