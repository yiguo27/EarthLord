//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示真实地图、用户位置、定位权限管理、圈地追踪
//

import SwiftUI
import CoreLocation

struct MapTabView: View {
    // MARK: - Observed Objects

    @ObservedObject private var languageManager = LanguageManager.shared
    @StateObject private var locationManager = LocationManager()

    // MARK: - State Properties

    /// 用户位置（双向绑定到地图）
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @State private var hasLocatedUser = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            // 主内容
            VStack(spacing: 0) {
                // 顶部标题栏
                headerView

                // 地图区域
                mapContentView
            }

            // 右下角按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 圈地按钮
                        trackingButton

                        // 定位按钮
                        relocateButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            // 页面出现时请求定位权限
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }
        }
    }

    // MARK: - Subviews

    /// 顶部标题栏
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                // 标题
                Text(languageManager.localizedString("地图"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 坐标显示
                if let location = userLocation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("LAT: \(String(format: "%.4f", location.latitude))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("LON: \(String(format: "%.4f", location.longitude))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // 副标题
            Text(languageManager.localizedString("探索和圈占领地"))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
        .background(ApocalypseTheme.background)
    }

    /// 地图内容区域
    private var mapContentView: some View {
        ZStack {
            if locationManager.isAuthorized {
                // 已授权：显示地图（包含轨迹渲染）
                MapViewRepresentable(
                    userLocation: $userLocation,
                    hasLocatedUser: $hasLocatedUser,
                    trackingPath: $locationManager.pathCoordinates,
                    pathUpdateVersion: locationManager.pathUpdateVersion,
                    isTracking: locationManager.isTracking
                )
                .ignoresSafeArea(edges: .bottom)
            } else if locationManager.isDenied {
                // 被拒绝：显示提示卡片
                permissionDeniedView
            } else {
                // 未决定：显示请求权限卡片
                requestPermissionView
            }
        }
    }

    /// 权限被拒绝提示视图
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                // 图标
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.warning)

                // 提示文字
                Text(languageManager.localizedString("定位权限被拒绝"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(languageManager.localizedString("请前往设置开启定位权限，以便在地图上显示您的位置"))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // 前往设置按钮
                Button(action: {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text(languageManager.localizedString("前往设置"))
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    /// 请求权限视图
    private var requestPermissionView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                // 图标
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                // 提示文字
                Text(languageManager.localizedString("需要定位权限"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(languageManager.localizedString("《地球新主》需要获取您的位置来显示您在末日世界中的坐标"))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // 请求权限按钮
                Button(action: {
                    locationManager.requestPermission()
                }) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                        Text(languageManager.localizedString("允许定位"))
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    /// 圈地追踪按钮
    private var trackingButton: some View {
        Button(action: {
            if locationManager.isTracking {
                locationManager.stopPathTracking()
            } else {
                locationManager.startPathTracking()
            }
        }) {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16, weight: .semibold))

                // 文字
                if locationManager.isTracking {
                    Text(languageManager.localizedString("停止圈地"))
                        .font(.system(size: 14, weight: .semibold))

                    // 显示当前点数
                    Text("(\(locationManager.pathCoordinates.count))")
                        .font(.system(size: 12, weight: .medium))
                } else {
                    Text(languageManager.localizedString("开始圈地"))
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .opacity(locationManager.isAuthorized ? 1 : 0)
    }

    /// 右下角重新定位按钮
    private var relocateButton: some View {
        Button(action: {
            // 重新居中到用户位置
            if let _ = userLocation {
                hasLocatedUser = false  // 重置标志，触发重新居中
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hasLocatedUser = true
                }
            }
        }) {
            Image(systemName: hasLocatedUser ? "location.fill" : "location")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(ApocalypseTheme.primary)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .opacity(locationManager.isAuthorized ? 1 : 0)
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
