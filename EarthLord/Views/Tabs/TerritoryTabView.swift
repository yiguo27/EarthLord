//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理页面 - 显示用户的领地列表
//

import SwiftUI
import CoreLocation

struct TerritoryTabView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var territoryManager = TerritoryManager.shared
    @ObservedObject private var authManager = OptimizedAuthManager.shared

    @State private var myTerritories: [Territory] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部标题栏
                    headerView

                    // 主内容区域
                    if isLoading {
                        loadingView
                    } else if myTerritories.isEmpty {
                        emptyStateView
                    } else {
                        territoryListView
                    }
                }
            }
            .onAppear {
                loadTerritories()
            }
            .onReceive(NotificationCenter.default.publisher(for: TerritoryManager.territoryUploadedNotification)) { _ in
                // 收到领地上传成功的通知，自动刷新列表
                loadTerritories()
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {
                    showError = false
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Subviews

    /// 顶部标题栏
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                // 标题
                Text(languageManager.localizedString("我的领地"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 刷新按钮
                Button(action: {
                    loadTerritories()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // 副标题
            HStack {
                Text(languageManager.localizedString("管理你的领地"))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 领地数量
                Text("\(myTerritories.count) 个领地")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
        .background(ApocalypseTheme.background)
    }

    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ApocalypseTheme.primary)

            Text("加载中...")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

                // 提示文字
                Text("还没有领地")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("前往地图页面开始圈占你的第一块领地吧！")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    /// 领地列表视图
    private var territoryListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(myTerritories) { territory in
                    NavigationLink(destination: TerritoryDetailView(territory: territory)) {
                        TerritoryCardView(territory: territory)
                    }
                    .buttonStyle(PlainButtonStyle()) // 防止按钮默认样式影响卡片外观
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Methods

    /// 加载领地列表
    private func loadTerritories() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                let territories = try await territoryManager.loadMyTerritories()
                await MainActor.run {
                    myTerritories = territories.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Territory Card View

struct TerritoryCardView: View {
    let territory: Territory
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：领地名称或 ID
            HStack {
                Image(systemName: "flag.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(territory.name ?? "领地 #\(territory.id.prefix(8))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 状态指示器
                if territory.isActive == true {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
            }

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.2))

            // 详细信息
            VStack(alignment: .leading, spacing: 8) {
                // 面积
                InfoRow(
                    icon: "square.on.square",
                    label: "面积",
                    value: String(format: "%.0f m²", territory.area)
                )

                // 点数
                if let pointCount = territory.pointCount {
                    InfoRow(
                        icon: "mappin.and.ellipse",
                        label: "路径点",
                        value: "\(pointCount) 个"
                    )
                }

                // 创建时间
                if let createdAt = territory.createdAt {
                    InfoRow(
                        icon: "clock.fill",
                        label: "创建时间",
                        value: formatDate(createdAt)
                    )
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

#Preview {
    TerritoryTabView()
}
