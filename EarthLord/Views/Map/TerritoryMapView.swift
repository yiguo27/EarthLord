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

        // 设置代理
        mapView.delegate = context.coordinator

        // 设置地图区域
        mapView.setRegion(region, animated: false)

        // 添加领地多边形
        if coordinates.count >= 3 {
            // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标（解决中国 GPS 偏移问题）
            let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)

            // 创建多边形
            let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            mapView.addOverlay(polygon)

            // 创建边界线
            let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            mapView.addOverlay(polyline)

            // 添加中心点标注
            let centerAnnotation = TerritoryAnnotation(
                coordinate: region.center,
                title: territoryName ?? "领地"
            )
            mapView.addAnnotation(centerAnnotation)
        }

        // 应用末世滤镜效果（可选）
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新地图区域
        uiView.setRegion(region, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 应用末世滤镜效果
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

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        /// 为覆盖物提供渲染器
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 处理多边形覆盖物
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                // 半透明橙色填充
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                // 橙色边框
                renderer.strokeColor = UIColor.systemOrange
                renderer.lineWidth = 3
                return renderer
            }

            // 处理折线覆盖物
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // 橙色轨迹
                renderer.strokeColor = UIColor.systemOrange
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        /// 为标注提供视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认蓝点
            if annotation is MKUserLocation {
                return nil
            }

            // 领地标注
            if let territoryAnnotation = annotation as? TerritoryAnnotation {
                let identifier = "TerritoryPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                // 设置标注样式
                annotationView?.markerTintColor = .systemOrange
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
