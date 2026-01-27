//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示真实地图、用户位置、定位权限管理、圈地追踪、速度警告、验证结果横幅
//

import SwiftUI
import CoreLocation

struct MapTabView: View {
    // MARK: - Observed Objects

    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var territoryManager = TerritoryManager.shared

    /// 定位管理器（通过环境对象注入，与全局共享同一实例）
    @EnvironmentObject var locationManager: LocationManager

    // MARK: - State Properties

    /// 用户位置（双向绑定到地图）
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @State private var hasLocatedUser = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 是否正在上传
    @State private var isUploading = false

    /// 上传结果消息
    @State private var uploadMessage: String?

    /// 是否显示上传结果提示
    @State private var showUploadAlert = false

    /// 追踪开始时间
    @State private var trackingStartTime: Date?

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

                // 地图区域（包含速度警告和验证结果横幅）
                ZStack(alignment: .top) {
                    // 地图内容
                    mapContentView

                    // 横幅区域（速度警告或验证结果）
                    VStack(spacing: 0) {
                        // 速度警告横幅（显示在地图上方）
                        speedWarningBanner

                        // 验证结果横幅（闭环后显示成功或失败）
                        if showValidationBanner {
                            validationResultBanner
                        }
                    }
                }
            }

            // 右下角按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 确认登记按钮（验证通过后显示）
                        if locationManager.territoryValidationPassed {
                            confirmButton
                        }

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
        // ⭐ 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
        // 上传结果提示
        .alert(uploadMessage ?? "", isPresented: $showUploadAlert) {
            Button("OK") {
                showUploadAlert = false
                uploadMessage = nil
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
                    isTracking: locationManager.isTracking,
                    isPathClosed: locationManager.isPathClosed,
                    territoryValidationPassed: locationManager.territoryValidationPassed
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

    /// 速度警告横幅
    private var speedWarningBanner: some View {
        Group {
            if let warning = locationManager.speedWarning {
                HStack(spacing: 8) {
                    // 警告图标
                    Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
                        .font(.system(size: 16, weight: .bold))

                    // 警告文字
                    Text(warning)
                        .font(.system(size: 14, weight: .semibold))

                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    // 根据是否还在追踪显示不同颜色
                    // 黄色：轻度超速警告（仍在追踪）
                    // 红色：严重超速（追踪已停止）
                    locationManager.isTracking ? Color.orange : Color.red
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: locationManager.speedWarning)
            }
        }
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            // 图标：成功用勾，失败用叉
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            // 文字：成功显示面积，失败显示错误原因
            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showValidationBanner)
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
                trackingStartTime = nil
            } else {
                trackingStartTime = Date()
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
            .background(
                // 根据状态显示不同颜色
                // 绿色：验证通过
                // 红色：验证失败或正在追踪
                // 主题色：未开始
                locationManager.isPathClosed ?
                    (locationManager.territoryValidationPassed ? Color.green : Color.red) :
                    (locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
            )
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

    /// 确认登记按钮（验证通过后显示）
    private var confirmButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(isUploading ? languageManager.localizedString("上传中...") : languageManager.localizedString("确认登记领地"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isUploading ? Color.gray : Color.green)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isUploading)
        .opacity(locationManager.isAuthorized ? 1 : 0)
    }

    // MARK: - Methods

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            uploadMessage = "领地验证未通过，无法上传"
            showUploadAlert = true
            return
        }

        // 检查是否有路径数据
        guard !locationManager.pathCoordinates.isEmpty else {
            uploadMessage = "没有路径数据"
            showUploadAlert = true
            return
        }

        isUploading = true

        do {
            // 使用追踪开始时间，如果没有则使用当前时间
            let startTime = trackingStartTime ?? Date()

            try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: startTime
            )

            // 上传成功
            uploadMessage = "领地登记成功！"
            showUploadAlert = true

            // ⚠️ 关键：上传成功后必须停止追踪！
            locationManager.stopPathTracking()
            trackingStartTime = nil

        } catch {
            // 上传失败
            uploadMessage = "上传失败: \(error.localizedDescription)"
            showUploadAlert = true
        }

        isUploading = false
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
}
