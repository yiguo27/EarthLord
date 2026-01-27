//
//  TestMenuView.swift
//  EarthLord
//
//  测试入口菜单 - 开发测试功能的入口页面
//  ⚠️ 不套 NavigationStack，因为它已经在 ContentView 的 NavigationStack 内部
//

import SwiftUI

struct TestMenuView: View {

    // MARK: - Body

    var body: some View {
        List {
            // Supabase 连接测试
            NavigationLink {
                SupabaseTestView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Supabase 连接测试")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("测试数据库连接和认证功能")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // 圈地功能测试
            NavigationLink {
                TerritoryTestView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("圈地功能测试")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("查看圈地模块的实时调试日志")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("开发测试")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
