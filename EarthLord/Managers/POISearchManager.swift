//
//  POISearchManager.swift
//  EarthLord
//
//  POI搜索管理器 - 使用MapKit搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation

/// POI搜索结果
struct SearchedPOI: Identifiable {
    let id: String
    let name: String
    let type: POIType
    let coordinate: CLLocationCoordinate2D
    let distance: Double  // 距离用户的米数
    var isScavenged: Bool = false  // 是否已搜刮

    /// POI类型
    enum POIType: String, CaseIterable {
        case store = "商店"
        case hospital = "医院"
        case pharmacy = "药店"
        case gasStation = "加油站"
        case restaurant = "餐厅"
        case cafe = "咖啡店"
        case convenience = "便利店"
        case unknown = "废墟"

        /// 对应的图标
        var iconName: String {
            switch self {
            case .store: return "bag.fill"
            case .hospital: return "cross.case.fill"
            case .pharmacy: return "pills.fill"
            case .gasStation: return "fuelpump.fill"
            case .restaurant: return "fork.knife"
            case .cafe: return "cup.and.saucer.fill"
            case .convenience: return "storefront.fill"
            case .unknown: return "building.2.fill"
            }
        }

        /// 对应的颜色
        var colorHex: String {
            switch self {
            case .store: return "#FF9500"      // 橙色
            case .hospital: return "#FF3B30"   // 红色
            case .pharmacy: return "#34C759"   // 绿色
            case .gasStation: return "#007AFF" // 蓝色
            case .restaurant: return "#FF9500" // 橙色
            case .cafe: return "#AF52DE"       // 紫色
            case .convenience: return "#FFCC00" // 黄色
            case .unknown: return "#8E8E93"    // 灰色
            }
        }

        /// 对应的危险等级（1-5），决定搜刮物品的稀有度分布
        var dangerLevel: Int {
            switch self {
            case .cafe:                              return 1
            case .store, .convenience, .restaurant:  return 2
            case .gasStation, .pharmacy:             return 3
            case .hospital:                          return 4
            case .unknown:                           return 3
            }
        }
    }
}

/// POI搜索管理器
class POISearchManager {

    // MARK: - Singleton

    static let shared = POISearchManager()

    private init() {}

    // MARK: - Public Methods

    /// 搜索附近的POI
    /// - Parameters:
    ///   - location: 搜索中心点
    ///   - radius: 搜索半径（米），默认1000米
    /// - Returns: 搜索到的POI列表
    func searchNearbyPOIs(
        at location: CLLocationCoordinate2D,
        radius: Double = 1000
    ) async throws -> [SearchedPOI] {

        print("🔍 POISearchManager: 开始搜索附近POI，半径\(Int(radius))米")

        // 要搜索的POI类型
        let searchCategories: [MKPointOfInterestCategory] = [
            .store,
            .hospital,
            .pharmacy,
            .gasStation,
            .restaurant,
            .cafe
        ]

        var allPOIs: [SearchedPOI] = []
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        // 对每种类型进行搜索
        for category in searchCategories {
            do {
                let pois = try await searchPOIs(
                    at: location,
                    radius: radius,
                    category: category,
                    userLocation: userLocation
                )
                allPOIs.append(contentsOf: pois)
            } catch {
                print("⚠️ 搜索 \(category.rawValue) 失败: \(error.localizedDescription)")
                // 继续搜索其他类型
            }
        }

        // 按距离排序
        allPOIs.sort { $0.distance < $1.distance }

        // 去重（根据名称和距离）
        var uniquePOIs: [SearchedPOI] = []
        var seenNames: Set<String> = []
        for poi in allPOIs {
            let key = "\(poi.name)-\(Int(poi.distance))"
            if !seenNames.contains(key) {
                seenNames.insert(key)
                uniquePOIs.append(poi)
            }
        }

        print("✅ POISearchManager: 找到 \(uniquePOIs.count) 个唯一POI")

        return uniquePOIs
    }

    // MARK: - Private Methods

    /// 搜索特定类型的POI
    private func searchPOIs(
        at location: CLLocationCoordinate2D,
        radius: Double,
        category: MKPointOfInterestCategory,
        userLocation: CLLocation
    ) async throws -> [SearchedPOI] {

        // 创建搜索请求
        let request = MKLocalPointsOfInterestRequest(
            center: location,
            radius: radius
        )
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])

        // 执行搜索
        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        // 转换结果
        let pois = response.mapItems.compactMap { item -> SearchedPOI? in
            guard let name = item.name else { return nil }

            let poiLocation = CLLocation(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
            let distance = userLocation.distance(from: poiLocation)

            // 只保留半径内的结果
            guard distance <= radius else { return nil }

            return SearchedPOI(
                id: UUID().uuidString,
                name: name,
                type: mapCategoryToType(category),
                coordinate: item.placemark.coordinate,
                distance: distance
            )
        }

        print("  📍 \(category.rawValue): 找到 \(pois.count) 个")

        return pois
    }

    /// 将MapKit类别映射到游戏POI类型
    private func mapCategoryToType(_ category: MKPointOfInterestCategory) -> SearchedPOI.POIType {
        switch category {
        case .store:
            return .store
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .gasStation:
            return .gasStation
        case .restaurant:
            return .restaurant
        case .cafe:
            return .cafe
        default:
            return .unknown
        }
    }
}
