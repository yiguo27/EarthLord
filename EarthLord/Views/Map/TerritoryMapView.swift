//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地详情地图视图 - 在混合地图上显示领地多边形
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

        // 延迟添加覆盖物，确保地图准备就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.addTerritoryOverlays(to: mapView, coordinates: coordinates, region: region)
        }

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
        print("\n========== 开始添加领地覆盖物 ==========")
        print("🗺️ 原始坐标数量 = \(coordinates.count)")

        guard coordinates.count >= 3 else {
            print("❌ 坐标点不足（需要至少3个点）")
            return
        }

        // 验证坐标有效性
        for (index, coord) in coordinates.enumerated() {
            print("📍 坐标[\(index)] = (\(coord.latitude), \(coord.longitude))")
            if coord.latitude < -90 || coord.latitude > 90 || coord.longitude < -180 || coord.longitude > 180 {
                print("❌ 坐标[\(index)]无效！")
                return
            }
        }

        // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标（解决中国 GPS 偏移问题）
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)
        print("🔄 转换后坐标数量 = \(gcj02Coordinates.count)")

        // 验证转换后的坐标
        for (index, coord) in gcj02Coordinates.enumerated() {
            print("🔄 转换后[\(index)] = (\(coord.latitude), \(coord.longitude))")
        }

        // ⚠️ 关键：使用 UnsafeMutablePointer 创建坐标数组（避免坐标被释放）
        let coordinatesPointer = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: gcj02Coordinates.count)
        for (index, coord) in gcj02Coordinates.enumerated() {
            coordinatesPointer[index] = coord
        }

        // 创建多边形（MKPolygon 会自动闭合）
        let polygon = MKPolygon(coordinates: coordinatesPointer, count: gcj02Coordinates.count)
        coordinatesPointer.deallocate()

        mapView.addOverlay(polygon, level: .aboveRoads)
        print("✅ 添加多边形覆盖物（自动闭合）")

        // 创建边界线（手动闭合以显示完整边界）
        var closedCoordinates = gcj02Coordinates
        if let first = gcj02Coordinates.first {
            closedCoordinates.append(first)
        }

        let polylinePointer = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: closedCoordinates.count)
        for (index, coord) in closedCoordinates.enumerated() {
            polylinePointer[index] = coord
        }

        let polyline = MKPolyline(coordinates: polylinePointer, count: closedCoordinates.count)
        polylinePointer.deallocate()

        mapView.addOverlay(polyline, level: .aboveRoads)
        print("✅ 添加边界线覆盖物（手动闭合，\(closedCoordinates.count)个点）")

        // 添加中心点标注
        let centerAnnotation = TerritoryAnnotation(
            coordinate: region.center,
            title: territoryName ?? "领地"
        )
        mapView.addAnnotation(centerAnnotation)
        print("✅ 添加中心点标注")
        print("========== 完成添加领地覆盖物 ==========\n")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var territoryCoordinates: [CLLocationCoordinate2D] = []

        /// 为覆盖物提供渲染器
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            print("\n🎨 rendererFor 被调用 - \(type(of: overlay))")

            // 处理多边形覆盖物（填充）
            if let polygon = overlay as? MKPolygon {
                print("🎨 创建多边形渲染器")
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 半透明绿色填充
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                // 绿色边框
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 3

                print("✅ 多边形渲染器配置完成 - 填充色: 绿色(0.3透明度), 边框: 绿色 3pt")
                return renderer
            }

            // 处理折线覆盖物（边界线）
            if let polyline = overlay as? MKPolyline {
                print("🎨 创建折线渲染器")
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 绿色轨迹
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round

                print("✅ 折线渲染器配置完成 - 颜色: 绿色, 宽度: 5pt")
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

                // 设置标注样式
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
