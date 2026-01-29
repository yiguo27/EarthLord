//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地详情地图视图 - 在混合地图上显示领地多边形
//  使用荧光色边界，确保与环境明显区分
//

import SwiftUI
import MapKit

/// 领地地图视图（显示领地多边形）
struct TerritoryMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let region: MKCoordinateRegion
    let territoryName: String?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // ⭐ 关键：设置为混合模式（卫星图+道路标签），显示街道和建筑物
        mapView.mapType = .hybrid

        // 显示POI标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .includingAll

        // 显示3D建筑
        mapView.showsBuildings = true

        // 允许用户缩放和拖动地图
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false  // 禁用3D倾斜
        mapView.isRotateEnabled = true

        // ⚠️ 关键：必须先设置代理，再添加覆盖物
        mapView.delegate = context.coordinator

        // 设置地图区域
        mapView.setRegion(region, animated: false)

        // ⚠️ 关键：不应用滤镜，保持颜色鲜艳
        // 不调用 applyApocalypseFilter，让荧光色保持明亮

        // 存储坐标到 coordinator
        context.coordinator.territoryCoordinates = coordinates

        // 立即添加覆盖物（不延迟，确保渲染）
        addTerritoryOverlays(to: mapView, coordinates: coordinates, region: region)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新地图区域
        uiView.setRegion(region, animated: false)

        // 检查坐标是否改变
        let coordinatesChanged = context.coordinator.territoryCoordinates.count != coordinates.count ||
            zip(context.coordinator.territoryCoordinates, coordinates).contains { coord1, coord2 in
                coord1.latitude != coord2.latitude || coord1.longitude != coord2.longitude
            }

        // 如果坐标改变，重新添加覆盖物
        if coordinatesChanged {
            context.coordinator.territoryCoordinates = coordinates

            // 先移除旧的覆盖物
            uiView.removeOverlays(uiView.overlays)
            uiView.removeAnnotations(uiView.annotations)

            // 添加新的覆盖物
            addTerritoryOverlays(to: uiView, coordinates: coordinates, region: region)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 添加领地覆盖物
    private func addTerritoryOverlays(to mapView: MKMapView, coordinates: [CLLocationCoordinate2D], region: MKCoordinateRegion) {
        print("\n🎯 ========== 开始添加领地覆盖物 ==========")
        print("🗺️ 原始坐标数量 = \(coordinates.count)")

        guard coordinates.count >= 3 else {
            print("❌ 坐标点不足（需要至少3个点）")
            return
        }

        // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标（解决中国 GPS 偏移问题）
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)
        print("🔄 GCJ-02 转换后坐标数量 = \(gcj02Coordinates.count)")

        // 打印前3个坐标验证
        for i in 0..<min(3, gcj02Coordinates.count) {
            print("🔄 转换后[\(i)] = (\(gcj02Coordinates[i].latitude), \(gcj02Coordinates[i].longitude))")
        }

        // 创建闭合的坐标数组（用于折线）
        var closedCoordinates = gcj02Coordinates
        if let first = gcj02Coordinates.first, let last = gcj02Coordinates.last {
            // 只有首尾不同时才添加
            let distance = sqrt(pow(first.latitude - last.latitude, 2) + pow(first.longitude - last.longitude, 2))
            if distance > 0.000001 {
                closedCoordinates.append(first)
                print("🔗 添加首点以闭合路径，总点数 = \(closedCoordinates.count)")
            } else {
                print("✓ 路径已闭合")
            }
        }

        // 创建折线（主要边界，最明显）
        let polyline = MKPolyline(coordinates: closedCoordinates, count: closedCoordinates.count)
        mapView.addOverlay(polyline, level: .aboveLabels)  // 在标签之上，最顶层
        print("✅ 添加主边界线（level: .aboveLabels）")

        // 创建多边形（填充区域）
        let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        mapView.addOverlay(polygon, level: .aboveRoads)  // 在道路之上
        print("✅ 添加多边形填充（level: .aboveRoads）")

        // 添加中心点标注
        let centerAnnotation = TerritoryAnnotation(
            coordinate: region.center,
            title: territoryName ?? "领地"
        )
        mapView.addAnnotation(centerAnnotation)
        print("✅ 添加中心点标注")
        print("🎯 ========== 完成添加领地覆盖物 ==========\n")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var territoryCoordinates: [CLLocationCoordinate2D] = []

        /// 为覆盖物提供渲染器
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            print("\n🎨 ========== rendererFor 被调用 ==========")
            print("🎨 覆盖物类型: \(type(of: overlay))")

            // 处理折线覆盖物（边界线）
            if let polyline = overlay as? MKPolyline {
                print("🎨 创建折线渲染器")
                let renderer = MKPolylineRenderer(polyline: polyline)

                // ⭐ 关键：使用荧光黄色 + 白色描边，确保极其明显
                // 荧光黄色：RGB(255, 255, 0)，非常鲜艳，与自然绿色完全不同
                renderer.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)  // 纯黄色
                renderer.lineWidth = 8  // 粗线，非常明显
                renderer.lineCap = .round
                renderer.lineJoin = .round

                // 添加白色描边效果（模拟阴影）
                renderer.alpha = 1.0  // 完全不透明

                print("✅ 折线渲染器配置:")
                print("   - 颜色: 荧光黄色 RGB(255,255,0)")
                print("   - 宽度: 8pt")
                print("   - 透明度: 1.0 (完全不透明)")
                print("🎨 ========================================\n")
                return renderer
            }

            // 处理多边形覆盖物（填充）
            if let polygon = overlay as? MKPolygon {
                print("🎨 创建多边形渲染器")
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 荧光黄色半透明填充
                renderer.fillColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.2)  // 黄色填充
                // 荧光黄色边框
                renderer.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
                renderer.lineWidth = 2

                print("✅ 多边形渲染器配置:")
                print("   - 填充色: 荧光黄色(0.2透明度)")
                print("   - 边框: 荧光黄色 2pt")
                print("🎨 ========================================\n")
                return renderer
            }

            print("⚠️ 未识别的覆盖物类型")
            return MKOverlayRenderer(overlay: overlay)
        }

        /// 为标注提供视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认蓝点
            if annotation is MKUserLocation {
                return nil
            }

            // 领地标注
            if annotation is TerritoryAnnotation {
                let identifier = "TerritoryPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                // 使用荧光黄色标注，与边界颜色一致
                annotationView?.markerTintColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
                annotationView?.glyphImage = UIImage(systemName: "flag.fill")

                return annotationView
            }

            return nil
        }
    }
}

// MARK: - Territory Annotation

/// 领地标注
class TerritoryAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?

    init(coordinate: CLLocationCoordinate2D, title: String?) {
        self.coordinate = coordinate
        self.title = title
        super.init()
    }
}
