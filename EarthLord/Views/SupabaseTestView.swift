//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by Yiguo27 on 2026/1/11.
//

import SwiftUI
import Supabase

/// Supabase连接测试视图
struct SupabaseTestView: View {
    // MARK: - 状态
    @State private var statusIcon: String = "questionmark.circle.fill"
    @State private var statusColor: Color = ApocalypseTheme.textSecondary
    @State private var debugLog: String = "点击下方按钮测试连接..."
    @State private var isTesting: Bool = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 状态图标
                Image(systemName: statusIcon)
                    .font(.system(size: 80))
                    .foregroundColor(statusColor)
                    .animation(.easeInOut(duration: 0.3), value: statusIcon)

                // 标题
                Text("Supabase 连接测试")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 调试日志文本框
                ScrollView {
                    Text(debugLog)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: 200)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)

                // 测试连接按钮
                Button(action: {
                    Task {
                        await testConnection()
                    }
                }) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "network")
                        }
                        Text(isTesting ? "测试中..." : "测试连接")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTesting ? ApocalypseTheme.textSecondary : ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .disabled(isTesting)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
        }
        .navigationTitle("Supabase测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 测试连接
    @MainActor
    private func testConnection() async {
        isTesting = true
        statusIcon = "arrow.triangle.2.circlepath"
        statusColor = ApocalypseTheme.warning
        debugLog = "正在测试连接...\n"
        debugLog += "URL: https://hrtdgvplerzybnodjqmk.supabase.co\n"
        debugLog += "Key: sb_publishable_aJg9Td...\n\n"

        do {
            // 故意查询一个不存在的表来测试连接
            let _ = try await supabase
                .from("non_existent_table")
                .select()
                .execute()

            // 如果没有抛出错误（理论上不应该发生）
            statusIcon = "checkmark.circle.fill"
            statusColor = ApocalypseTheme.success
            debugLog += "✅ 连接成功"

        } catch {
            let errorMessage = error.localizedDescription
            debugLog += "服务器响应: \(errorMessage)\n\n"

            // 分析错误类型
            if errorMessage.contains("PGRST") || errorMessage.contains("Could not find the table") {
                // PostgreSQL REST API 错误 = 服务器已响应
                statusIcon = "checkmark.circle.fill"
                statusColor = ApocalypseTheme.success
                debugLog += "✅ 连接成功（服务器已响应）"
            } else if errorMessage.contains("relation") && errorMessage.contains("does not exist") {
                // 表不存在错误 = 连接成功
                statusIcon = "checkmark.circle.fill"
                statusColor = ApocalypseTheme.success
                debugLog += "✅ 连接成功（服务器已响应）"
            } else if errorMessage.contains("hostname") ||
                      errorMessage.contains("URL") ||
                      errorMessage.contains("NSURLErrorDomain") {
                // 网络错误
                statusIcon = "exclamationmark.circle.fill"
                statusColor = ApocalypseTheme.danger
                debugLog += "❌ 连接失败：URL错误或无网络"
            } else {
                // 其他错误
                statusIcon = "exclamationmark.circle.fill"
                statusColor = ApocalypseTheme.danger
                debugLog += "❌ 错误: \(errorMessage)"
                print("Supabase Error: \(error)")
            }
        }

        isTesting = false
    }
}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
