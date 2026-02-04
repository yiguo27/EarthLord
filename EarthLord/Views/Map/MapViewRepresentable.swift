//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView的SwiftUI包装器 - 将UIKit的地图组件桥接到SwiftUI
//  支持末世滤镜、路径追踪轨迹渲染、验证结果变色、多边形填充
//

import SwiftUI
import MapKit

// MARK: - POI 注解

/// POI 地图注解（探索中在地图上显示可搜刮的废墟点）
class POIAnnotation: MKPointAnnotation {
    let poi: SearchedPOI

    init(poi: SearchedPOI) {
        self.poi = poi
        super.init()
        self.coordinate = poi.coordinate
        self.title = poi.name
        self.subtitle = poi.type.rawValue
    }
}

// MARK: - MapViewRepresentable

/// 地图视图包装器
/// 功能：显示苹果地图、应用末世滤镜、处理用户位置更新、自动居中、轨迹渲染、验证结果变色、多边形填充、显示其他领地
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Binding Properties

    /// 用户位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    /// 追踪路径坐标数组（WGS-84 坐标）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    // MARK: - Properties

    /// 路径更新版本号（用于触发轨迹更新）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否闭合（用于轨迹变色和多边形填充）
    var isPathClosed: Bool

    /// 领地验证是否通过（用于确定轨迹颜色：通过=绿色，失败=红色）
    var territoryValidationPassed: Bool = false

    /// 所有其他用户的领地数据（用于在地图上显示黄色领地）
    var otherTerritories: [Territory] = []

    /// 当前用户 ID（用于过滤自己的领地）
    var currentUserId: String?

    /// 附近可搜刮的 POI 列表（探索中在地图上显示废墟标记）
    var searchedPOIs: [SearchedPOI] = []

    // MARK: - UIViewRepresentable Methods

    /// 创建地图视图
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 设置地图类型为混合（卫星图+道路标签，符合末世废土风格）
        mapView.mapType = .hybrid

        // 隐藏默认的POI标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏3D建筑（简化视觉效果）
        mapView.showsBuildings = false

        // ⭐ 关键：显示用户位置蓝点
        mapView.showsUserLocation = true

        // 允许用户缩放和拖动地图
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false  // 禁用3D倾斜
        mapView.isRotateEnabled = true

        // ⭐ 关键：设置代理，用于处理位置更新和轨迹渲染
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    /// 更新地图视图
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // ⭐ 关键：检测路径更新版本变化、闭环状态变化或验证状态变化，更新轨迹显示
        let needsUpdate = context.coordinator.lastPathVersion != pathUpdateVersion ||
                          context.coordinator.lastClosedState != isPathClosed ||
                          context.coordinator.lastValidationState != territoryValidationPassed

        if needsUpdate {
            context.coordinator.lastPathVersion = pathUpdateVersion
            context.coordinator.lastClosedState = isPathClosed
            context.coordinator.lastValidationState = territoryValidationPassed
            updateTrackingPath(on: uiView, coordinator: context.coordinator)
        }

        // ⭐ 更新其他领地显示（当领地数据变化时）
        let territoriesCount = otherTerritories.count
        if context.coordinator.lastTerritoriesCount != territoriesCount {
            context.coordinator.lastTerritoriesCount = territoriesCount
            updateOtherTerritories(on: uiView, coordinator: context.coordinator)
        }

        // ⭐ 更新 POI 废墟标记（探索中附近可搜刮地点）
        let poiSignature = searchedPOIs.map { "\($0.id)-\($0.isScavenged)" }.joined(separator: ",")
        if context.coordinator.lastPOISignature != poiSignature {
            context.coordinator.lastPOISignature = poiSignature
            updatePOIAnnotations(on: uiView)
        }
    }

    /// 创建协调器（处理地图代理回调）
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 应用末世滤镜效果
    /// - Parameter mapView: 要应用滤镜的地图视图
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度，营造荒凉感
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey)    // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey)

        // 应用滤镜到地图图层
        if let colorControls = colorControls, let sepiaFilter = sepiaFilter {
            mapView.layer.filters = [colorControls, sepiaFilter]
        }
    }

    /// 更新追踪路径显示
    /// - Parameters:
    ///   - mapView: 地图视图
    ///   - coordinator: 协调器（用于访问闭环状态）
    private func updateTrackingPath(on mapView: MKMapView, coordinator: Coordinator) {
        // 移除旧的轨迹覆盖物（折线和多边形）
        let existingOverlays = mapView.overlays.filter { $0 is MKPolyline || $0 is MKPolygon }
        mapView.removeOverlays(existingOverlays)

        // 如果路径点少于 2 个，无法绘制线段
        guard trackingPath.count >= 2 else { return }

        // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标（解决中国 GPS 偏移问题）
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(trackingPath)

        // 创建折线覆盖物
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)

        // 添加折线到地图
        mapView.addOverlay(polyline)

        // ⭐ 关键：如果路径已闭合且验证通过且点数 >= 3，创建多边形填充
        if isPathClosed && territoryValidationPassed && gcj02Coordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            // 先添加多边形（在下层），再添加折线（在上层）
            mapView.insertOverlay(polygon, below: polyline)
            print("🟩 添加闭环多边形填充（验证通过）")
        }

        print("🗺️ 更新轨迹：\(trackingPath.count) 个点，闭环状态：\(isPathClosed)，验证通过：\(territoryValidationPassed)")
    }

    /// 更新其他用户的领地显示（黄色覆盖物）
    /// - Parameters:
    ///   - mapView: 地图视图
    ///   - coordinator: 协调器
    private func updateOtherTerritories(on mapView: MKMapView, coordinator: Coordinator) {
        print("\n🟨 ========== 开始更新其他领地显示 ==========")

        // 移除旧的其他领地覆盖物（使用特殊标记识别）
        let existingTerritoryOverlays = mapView.overlays.filter { overlay in
            if let polyline = overlay as? MKPolyline {
                return polyline.title == "OtherTerritory"
            }
            if let polygon = overlay as? MKPolygon {
                return polygon.title == "OtherTerritory"
            }
            return false
        }
        mapView.removeOverlays(existingTerritoryOverlays)
        print("🗑️ 移除旧的其他领地覆盖物: \(existingTerritoryOverlays.count) 个")

        // 过滤掉当前用户的领地，只显示其他用户的
        let displayTerritories: [Territory]
        if let userId = currentUserId {
            displayTerritories = otherTerritories.filter { $0.userId.lowercased() != userId.lowercased() }
        } else {
            displayTerritories = otherTerritories
        }

        print("📊 准备显示 \(displayTerritories.count) 个其他用户的领地")

        // 为每个其他领地添加黄色覆盖物
        for territory in displayTerritories {
            let coordinates = territory.toCoordinates()
            guard coordinates.count >= 3 else {
                print("⚠️ 领地 \(territory.id.prefix(8)) 坐标不足，跳过")
                continue
            }

            // 转换为 GCJ-02 坐标
            let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)

            // 创建黄色多边形填充
            let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            polygon.title = "OtherTerritory"  // 标记为其他领地
            polygon.subtitle = territory.id   // 存储领地 ID

            // 创建黄色折线边界
            let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            polyline.title = "OtherTerritory"  // 标记为其他领地
            polyline.subtitle = territory.id   // 存储领地 ID

            // 先添加多边形（下层），再添加折线（上层）
            mapView.addOverlay(polygon, level: .aboveRoads)
            mapView.addOverlay(polyline, level: .aboveRoads)

            print("🟨 添加其他领地: \(territory.id.prefix(8))，\(gcj02Coordinates.count) 个点")
        }

        print("🟨 ========== 完成更新其他领地显示 ==========\n")
    }

    /// 更新 POI 废墟注解标记（移除已搜刮的，添加未搜刮的）
    private func updatePOIAnnotations(on mapView: MKMapView) {
        // 移除旧的 POI 注解
        let existing = mapView.annotations.compactMap { $0 as? POIAnnotation }
        mapView.removeAnnotations(existing)

        // 添加未搜刮的 POI
        let annotations = searchedPOIs.filter { !$0.isScavenged }.map { POIAnnotation(poi: $0) }
        mapView.addAnnotations(annotations)
        print("📍 更新 POI 标记: 显示 \(annotations.count) 个废墟点")
    }

    // MARK: - Coordinator

    /// 地图代理协调器
    /// 功能：处理地图事件、实现自动居中逻辑、轨迹渲染、验证结果变色
    class Coordinator: NSObject, MKMapViewDelegate {

        // MARK: - Properties

        /// 父视图引用
        var parent: MapViewRepresentable

        /// 首次居中标志（防止重复自动居中）
        private var hasInitialCentered = false

        /// 上次路径更新版本号（用于检测变化）
        var lastPathVersion: Int = 0

        /// 上次闭环状态（用于检测闭环状态变化，触发轨迹颜色更新）
        var lastClosedState: Bool = false

        /// 上次验证状态（用于检测验证状态变化，触发轨迹颜色更新）
        var lastValidationState: Bool = false

        /// 上次其他领地数量（用于检测领地数据变化）
        var lastTerritoriesCount: Int = 0

        /// 上次 POI 签名（用于检测 POI 列表变化）
        var lastPOISignature: String = ""

        // MARK: - Initialization

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate Methods

        /// ⭐ 关键方法：用户位置更新时调用
        /// 功能：更新绑定的位置数据，首次获得位置时自动居中地图
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置坐标
            guard let location = userLocation.location else { return }

            // 更新父视图的位置绑定
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 如果已经完成首次居中，则不再自动居中（避免干扰用户手动拖动）
            guard !hasInitialCentered else { return }

            // 创建居中区域（约1公里范围，适合查看周边环境）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // ⭐ 平滑居中地图到用户位置
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新父视图的状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// ⭐ 关键方法：为覆盖物提供渲染器（轨迹线样式 + 多边形填充 + 其他领地黄色显示）
        /// 注意：必须实现此方法，否则轨迹添加了也看不见！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 处理折线覆盖物（轨迹线）
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 🟨 检查是否是其他领地的折线（通过 title 标识）
                if polyline.title == "OtherTerritory" {
                    // 其他用户的领地：鲜明的金黄色边界
                    renderer.strokeColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)  // 金黄色
                    renderer.lineWidth = 6
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                    return renderer
                }

                // ⭐ 关键：根据闭环状态和验证结果设置自己的轨迹颜色
                if parent.isPathClosed {
                    if parent.territoryValidationPassed {
                        // 验证通过：鲜明的亮绿色轨迹
                        renderer.strokeColor = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)  // 纯绿色
                    } else {
                        // 验证失败：鲜明的红色轨迹
                        renderer.strokeColor = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)  // 亮红色
                    }
                } else {
                    // 未闭环：鲜明的亮绿色轨迹（方便用户看清自己的行走路径）
                    renderer.strokeColor = UIColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1.0)  // 亮绿色
                }

                renderer.lineWidth = 6                    // 加粗线宽 6pt
                renderer.lineCap = .round                 // 圆头线帽
                renderer.lineJoin = .round                // 圆角连接

                return renderer
            }

            // 处理多边形覆盖物（闭环区域填充）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 🟨 检查是否是其他领地的多边形（通过 title 标识）
                if polygon.title == "OtherTerritory" {
                    // 其他用户的领地：半透明金黄色填充
                    renderer.fillColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 0.3)  // 金黄色填充
                    renderer.strokeColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)  // 金黄色边框
                    renderer.lineWidth = 4
                    return renderer
                }

                // 自己的领地：半透明亮绿色填充
                renderer.fillColor = UIColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 0.3)  // 亮绿色填充
                renderer.strokeColor = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)  // 纯绿色边框
                renderer.lineWidth = 4

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        /// 为 POI 注解提供自定义标记视图（彩色圆形 + 底部三角指针）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let poiAnnotation = annotation as? POIAnnotation else { return nil }

            let identifier = "POIMarker"
            let annotationView: MKAnnotationView
            if let reused = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                reused.annotation = poiAnnotation
                annotationView = reused
            } else {
                annotationView = MKAnnotationView(annotation: poiAnnotation, reuseIdentifier: identifier)
            }

            annotationView.canShowCallout = true
            annotationView.centerOffset = CGPoint(x: 0, y: -14)

            // 用 POI 类型颜色生成圆形标记 + 底部三角指针
            let color = UIColor(Color(hex: poiAnnotation.poi.type.colorHex))
            let size: CGFloat = 26
            let totalHeight = size + 10
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: totalHeight))
            annotationView.image = renderer.image { ctx in
                let g = ctx.cgContext
                // 白色外圈
                UIColor.white.setFill()
                g.addEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                g.fillPath()
                // 彩色内圈
                color.setFill()
                g.addEllipse(in: CGRect(x: 2.5, y: 2.5, width: size - 5, height: size - 5))
                g.fillPath()
                // 底部三角指针
                let mid = size / 2
                color.setFill()
                g.move(to: CGPoint(x: mid - 5, y: size - 2))
                g.addLine(to: CGPoint(x: mid + 5, y: size - 2))
                g.addLine(to: CGPoint(x: mid, y: totalHeight - 1))
                g.closePath()
                g.fillPath()
            }

            return annotationView
        }

        /// 地图区域改变完成时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可用于追踪用户手动移动地图（暂不需要实现）
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 可用于地图加载完成后的额外配置（暂不需要实现）
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false,
        territoryValidationPassed: false,
        otherTerritories: [],
        currentUserId: nil
    )
}
