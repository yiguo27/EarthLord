//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地详情地图视图 - 直接复制地图标签页的成功实现
//  使用荧光黄色边界，确保与环境明显区分
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

        // 存储坐标到 coordinator
        context.coordinator.territoryCoordinates = coordinates

        // ⭐ 关键：首次创建时立即添加覆盖物
        updateTerritoryOverlays(on: mapView, coordinator: context.coordinator)

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
            updateTerritoryOverlays(on: uiView, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 更新领地覆盖物（完全复制地图标签页的成功实现）
    private func updateTerritoryOverlays(on mapView: MKMapView, coordinator: Coordinator) {
        print("\n🚀 ========== 开始更新领地覆盖物 ==========")

        // 移除旧的轨迹覆盖物（折线和多边形）
        let existingOverlays = mapView.overlays.filter { $0 is MKPolyline || $0 is MKPolygon }
        mapView.removeOverlays(existingOverlays)
        print("🗑️ 移除旧覆盖物: \(existingOverlays.count) 个")

        // 移除旧标注
        let existingAnnotations = mapView.annotations.filter { $0 is TerritoryAnnotation }
        mapView.removeAnnotations(existingAnnotations)

        // 如果路径点少于 3 个，无法绘制多边形
        guard coordinates.count >= 3 else {
            print("❌ 坐标点不足（需要至少3个点）")
            return
        }

        // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标（解决中国 GPS 偏移问题）
        // 完全复制地图标签页的实现，不使用 UnsafeMutablePointer
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)
        print("🔄 GCJ-02 转换: \(coordinates.count) -> \(gcj02Coordinates.count) 个坐标")

        // 打印前3个坐标验证
        for i in 0..<min(3, gcj02Coordinates.count) {
            print("   坐标[\(i)] = (\(gcj02Coordinates[i].latitude), \(gcj02Coordinates[i].longitude))")
        }

        // ⭐ 创建折线覆盖物（完全复制地图标签页的实现）
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)

        // 添加折线到地图
        mapView.addOverlay(polyline)
        print("✅ 添加折线覆盖物（\(gcj02Coordinates.count) 个点）")

        // ⭐ 创建多边形填充（完全复制地图标签页的实现）
        let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)

        // 先添加多边形（在下层），再添加折线（在上层）
        mapView.insertOverlay(polygon, below: polyline)
        print("✅ 添加多边形填充（在折线下层）")

        // 添加中心点标注
        let centerAnnotation = TerritoryAnnotation(
            coordinate: region.center,
            title: territoryName ?? "领地"
        )
        mapView.addAnnotation(centerAnnotation)
        print("✅ 添加中心点标注")

        print("🚀 ========== 完成更新领地覆盖物 ==========\n")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var territoryCoordinates: [CLLocationCoordinate2D] = []

        /// 为覆盖物提供渲染器（完全复制地图标签页的绿色样式）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            print("\n🎨 rendererFor 被调用 - \(type(of: overlay))")

            // 处理折线覆盖物（边界线）- 完全复制地图标签页的实现
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // ⭐ 关键：使用系统绿色（与地图标签页完全一样）
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 5  // 与地图标签页一样的粗细
                renderer.lineCap = .round
                renderer.lineJoin = .round

                print("✅ 折线渲染器: 系统绿色 5pt（与地图标签页一致）")
                return renderer
            }

            // 处理多边形覆盖物（填充）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 半透明绿色填充（与地图标签页一致）
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                // 绿色边框
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2

                print("✅ 多边形渲染器: 系统绿色填充 + 边框（与地图标签页一致）")
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

                // 系统绿色标注（与地图标签页一致）
                annotationView?.markerTintColor = .systemGreen
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
