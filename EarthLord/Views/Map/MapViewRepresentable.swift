//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView的SwiftUI包装器 - 将UIKit的地图组件桥接到SwiftUI
//  支持末世滤镜、路径追踪轨迹渲染
//

import SwiftUI
import MapKit

// MARK: - MapViewRepresentable

/// 地图视图包装器
/// 功能：显示苹果地图、应用末世滤镜、处理用户位置更新、自动居中、轨迹渲染
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
        // ⭐ 关键：检测路径更新版本变化，更新轨迹显示
        if context.coordinator.lastPathVersion != pathUpdateVersion {
            context.coordinator.lastPathVersion = pathUpdateVersion
            updateTrackingPath(on: uiView)
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
    /// - Parameter mapView: 地图视图
    private func updateTrackingPath(on mapView: MKMapView) {
        // 移除旧的轨迹覆盖物
        let existingOverlays = mapView.overlays.filter { $0 is MKPolyline }
        mapView.removeOverlays(existingOverlays)

        // 如果路径点少于 2 个，无法绘制线段
        guard trackingPath.count >= 2 else { return }

        // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标（解决中国 GPS 偏移问题）
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(trackingPath)

        // 创建折线覆盖物
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)

        // 添加到地图
        mapView.addOverlay(polyline)

        print("🗺️ 更新轨迹：\(trackingPath.count) 个点")
    }

    // MARK: - Coordinator

    /// 地图代理协调器
    /// 功能：处理地图事件、实现自动居中逻辑、轨迹渲染
    class Coordinator: NSObject, MKMapViewDelegate {

        // MARK: - Properties

        /// 父视图引用
        var parent: MapViewRepresentable

        /// 首次居中标志（防止重复自动居中）
        private var hasInitialCentered = false

        /// 上次路径更新版本号（用于检测变化）
        var lastPathVersion: Int = 0

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

        /// ⭐ 关键方法：为覆盖物提供渲染器（轨迹线样式）
        /// 注意：必须实现此方法，否则轨迹添加了也看不见！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 检查是否是折线覆盖物
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 设置轨迹线样式
                renderer.strokeColor = UIColor.cyan       // 青色（末世科技感）
                renderer.lineWidth = 5                    // 线宽 5pt
                renderer.lineCap = .round                 // 圆头线帽
                renderer.lineJoin = .round                // 圆角连接

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
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
        isTracking: false
    )
}
