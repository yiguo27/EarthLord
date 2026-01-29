//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情视图 - 在地图上显示领地的位置和形状
//

import SwiftUI
import MapKit
import CoreLocation

struct TerritoryDetailView: View {
    let territory: Territory
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var region: MKCoordinateRegion
    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    init(territory: Territory) {
        self.territory = territory

        // 计算领地中心点和范围
        let coordinates = territory.toCoordinates()
        print("🏁 TerritoryDetailView: 领地 ID = \(territory.id.prefix(8))")
        print("🏁 TerritoryDetailView: path 数组长度 = \(territory.path.count)")
        print("🏁 TerritoryDetailView: 转换后坐标数量 = \(coordinates.count)")

        if coordinates.isEmpty {
            // 如果没有坐标，使用默认位置
            print("❌ TerritoryDetailView: 坐标为空，使用默认位置")
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            print("✅ TerritoryDetailView: 第一个坐标 = (\(coordinates[0].latitude), \(coordinates[0].longitude))")
            _region = State(initialValue: Self.calculateRegion(from: coordinates))
        }
    }

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航栏
                navigationBar

                // 地图区域
                mapView

                // 底部信息卡片
                infoCard
            }
        }
        .navigationBarHidden(true)
        .alert("删除领地", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteTerritory()
            }
        } message: {
            Text("确定要删除这块领地吗？此操作无法撤销。")
        }
    }

    // MARK: - Subviews

    /// 顶部导航栏
    private var navigationBar: some View {
        HStack {
            // 返回按钮
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("返回")
                        .font(.system(size: 16))
                }
                .foregroundColor(ApocalypseTheme.primary)
            }

            Spacer()

            // 标题
            Text(territory.name ?? "领地详情")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 删除按钮
            Button(action: {
                showDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
            }
            .disabled(isDeleting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.background)
    }

    /// 地图视图
    private var mapView: some View {
        let coordinates = territory.toCoordinates()
        print("📍 TerritoryDetailView.mapView: 传递给地图的坐标数量 = \(coordinates.count)")

        return TerritoryMapView(
            coordinates: coordinates,
            region: region,
            territoryName: territory.name
        )
        .frame(maxWidth: .infinity)
        .frame(height: 400)
    }

    /// 底部信息卡片
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("领地信息")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.2))

            // 详细信息列表
            VStack(alignment: .leading, spacing: 12) {
                // ID
                DetailInfoRow(
                    icon: "number",
                    label: "领地 ID",
                    value: "#\(territory.id.prefix(8))"
                )

                // 面积
                DetailInfoRow(
                    icon: "square.on.square",
                    label: "面积",
                    value: String(format: "%.0f m²", territory.area)
                )

                // 点数
                if let pointCount = territory.pointCount {
                    DetailInfoRow(
                        icon: "mappin.and.ellipse",
                        label: "路径点数",
                        value: "\(pointCount) 个"
                    )
                }

                // 创建时间
                if let createdAt = territory.createdAt {
                    DetailInfoRow(
                        icon: "clock.fill",
                        label: "创建时间",
                        value: formatDate(createdAt)
                    )
                }

                // 状态
                DetailInfoRow(
                    icon: "checkmark.circle.fill",
                    label: "状态",
                    value: territory.isActive == true ? "活跃" : "非活跃"
                )
            }
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
    }

    // MARK: - Methods

    /// 删除领地
    private func deleteTerritory() {
        Task {
            isDeleting = true
            do {
                try await TerritoryManager.shared.deleteTerritory(id: territory.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ 删除领地失败: \(error)")
                isDeleting = false
            }
        }
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 计算区域范围（精准聚焦领地）
    static func calculateRegion(from coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        // ⭐ 先转换为 GCJ-02 坐标（中国地图偏移校准）
        let gcj02Coords = CoordinateConverter.wgs84ToGcj02(coordinates)

        var minLat = gcj02Coords[0].latitude
        var maxLat = gcj02Coords[0].latitude
        var minLon = gcj02Coords[0].longitude
        var maxLon = gcj02Coords[0].longitude

        for coord in gcj02Coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // ⭐ 精准模式：只增加 20% 边距（原来是 50%）
        // 确保领地占据大部分屏幕，位置更精准
        let latDelta = max((maxLat - minLat) * 1.2, 0.002) // 最小 200 米范围
        let lonDelta = max((maxLon - minLon) * 1.2, 0.002)

        let span = MKCoordinateSpan(
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )

        print("📍 精准定位：中心点 = (\(center.latitude), \(center.longitude))")
        print("📍 缩放范围：latΔ = \(latDelta), lonΔ = \(lonDelta)")

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Detail Info Row

struct DetailInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    TerritoryDetailView(territory: Territory(
        id: "preview-id",
        userId: "user-id",
        name: "测试领地",
        path: [
            ["lat": 39.9042, "lon": 116.4074],
            ["lat": 39.9052, "lon": 116.4074],
            ["lat": 39.9052, "lon": 116.4084],
            ["lat": 39.9042, "lon": 116.4084]
        ],
        area: 1234.5,
        pointCount: 4,
        isActive: true,
        createdAt: Date(),
        startedAt: Date(),
        completedAt: Date()
    ))
}
