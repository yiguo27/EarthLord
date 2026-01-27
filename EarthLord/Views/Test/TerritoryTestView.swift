//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地功能测试界面 - 真机测试时在手机上直接查看日志
//  ⚠️ 不套 NavigationStack，因为是从 TestMenuView 导航进来的
//

import SwiftUI

struct TerritoryTestView: View {

    // MARK: - Environment & Observed Objects

    /// 定位管理器（通过环境对象注入，与全局共享同一实例）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器（单例）
    @ObservedObject private var logger = TerritoryLogger.shared

    // MARK: - State

    /// 是否显示分享面板
    @State private var showingShareSheet = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：状态指示器
            trackingStatusIndicator

            // 中间：日志滚动区域
            logScrollArea

            // 底部：操作按钮
            actionButtons
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [logger.export()])
        }
        .onAppear {
            logger.info("测试界面已打开")
        }
    }

    // MARK: - 顶部：状态指示器

    /// 追踪状态指示器
    private var trackingStatusIndicator: some View {
        HStack(spacing: 10) {
            // 状态圆点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 12, height: 12)

            // 状态文字
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(locationManager.isTracking ? .green : .secondary)

            Spacer()

            // 路径点数（追踪时显示）
            if locationManager.isTracking {
                Text("\(locationManager.pathCoordinates.count) 个点")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // 闭环状态
            if locationManager.isPathClosed {
                Text("已闭环")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }

    // MARK: - 中间：日志滚动区域

    /// 日志滚动区域
    private var logScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logger.logs) { entry in
                        // 单条日志
                        HStack(alignment: .top, spacing: 8) {
                            // 时间戳
                            Text("[\(entry.timeString)]")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)

                            // 类型标签
                            Text("[\(entry.type.rawValue)]")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(entry.type.color)

                            // 内容
                            Text(entry.message)
                                .font(.system(size: 13))
                                .foregroundColor(entry.type.color)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                    }

                    // 底部锚点（用于自动滚动）
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, 8)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .onChange(of: logger.logText) { _ in
                // 日志更新时自动滚动到底部
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 底部：操作按钮

    /// 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // 清空日志按钮
            Button(action: {
                logger.clear()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.85))
                .cornerRadius(10)
            }

            // 导出日志按钮
            Button(action: {
                showingShareSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出日志")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - ShareSheet 分享面板

/// iOS 系统分享面板包装器
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
